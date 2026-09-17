# Lab 5 - OCI Architect Pro Exam - Zero Trust Packet Routing

#7_mystudy #OCI  
**Plan item:** extend Week 2's network-security work (Module: Network Security) with hands-on Zero Trust Packet Routing (ZPR) — provision the MyLearn "Scenario" lab (VM-01 → VM-02 SSH lockdown) via Terraform, not just diagram it.

**Companion references:** [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]] for the full ZPR concept writeup (Science App and CarCo MyLearn scenarios, the four-pillar pitch, policy syntax) and [[terraform/LABS.md]] for the `lab-zpr-stack` build this lab documents. [[Lab 4 - OCI Architect Pro Exam - Vault, Guard, Zones, Logging, Network Boundary]] for the NSG/security-list layer this lab's ZPR policy sits on top of.

**Split approach, and why:** unlike Lab 4's Cloud Guard/Security Zones/WAF split, this lab's entire scope was safe to actually apply: no tenancy-wide singleton risk beyond `oci_zpr_configuration` itself (ZPR onboarding is additive — it does not retroactively restrict existing resources the way a Security Zone recipe does), and no meaningful cost (2 small ARM Compute instances). This lab **was fully applied** to the live tenancy, not just dry-run planned — Part A below is a real build, and the stack is currently live in `sandbox` as of this writing.

---

## Part A — Built and applied for real

### A1. Reproduce the MyLearn scenario topology

MyLearn's "OCI ZPR" scenario: one VCN, one public subnet, two Compute instances (VM-01, VM-02), and a stated goal — "Restrict SSH access to VM-02 from the internet" / "Allow SSH access to VM-02 only from VM-01." The starting security list is deliberately over-permissive: stateful ingress TCP/22 from `0.0.0.0/0`.

**Terraform (`terraform/lab-zpr-stack/main.tf`):** VCN (`10.0.0.0/16`), IGW, public route table, a security list matching the scenario's exact starting rule (TCP/22 from `0.0.0.0/0`, all egress), one public subnet, two `VM.Standard.A1.Flex` instances.

- [x] VCN, IGW, route table, security list, subnet created
- [x] VM-01 and VM-02 created and `RUNNING` on the same public subnet

### A2. Network-layer fix first — the scenario's own stated remediation

Before touching ZPR, the scenario asks for a conventional fix: an NSG on VM-02 allowing SSH only from VM-01's address, not the internet at large.

```hcl
resource "oci_core_network_security_group_security_rule" "vm02_allow_ssh_from_vm01" {
  network_security_group_id = oci_core_network_security_group.vm02_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  # CIDR_BLOCK requires an actual CIDR, not a bare IP — confirmed by a real
  # 400 ("CIDR 10.0.1.75 is invalid: unable to parse") on first apply against
  # oci_core_instance.vm_01.private_ip alone; /32 makes it a valid single-host CIDR.
  source      = "${oci_core_instance.vm_01.private_ip}/32"
  source_type = "CIDR_BLOCK"
  stateless   = false
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}
```

**Bug found: `private_ip` alone is not a valid `CIDR_BLOCK` value.** The first apply attempt used `oci_core_instance.vm_01.private_ip` directly (e.g. `10.0.1.75`) and got a real `400 InvalidParameter: "The requested CIDR 10.0.1.75 is invalid: unable to parse"`. `CIDR_BLOCK` source type requires an actual CIDR — appending `/32` fixed it. This is a small, easy-to-miss gap between "this looks like a valid address" and "this is a valid CIDR block," worth remembering since the error message doesn't say "append /32," just that parsing failed.

**Design note carried over from Note 5's ZPR section:** this NSG rule is exactly the kind of hand-authored, address-based rule that MyLearn's own NSG-bug slide showed going wrong — a single mistyped CIDR digit slipped past a two-person authoring/approval process undetected. This lab's NSG rule references `oci_core_instance.vm_01.private_ip` as a live Terraform attribute rather than a typed literal specifically to avoid that exact failure mode, though in a hand-typed real-world NSG rule (not a Terraform-managed one) that protection doesn't exist — the address still has to be transcribed correctly by a human.

- [x] NSG created, scoped to VM-02
- [x] Ingress rule restricts SSH to VM-01's private IP (as a `/32`) only — applied and live

### A3. ZPR layer — the part that holds even if A2's NSG is later misconfigured

This is the lab's actual point: provision a ZPR policy that enforces the same "VM-01 → VM-02 only" intent independent of whatever the NSG or security list say, per Note 5's CarCo lesson ("networking changes can't invalidate ZPR security policies").

**Final, working resource set — after five real bugs, all confirmed by live API errors, not guesswork:**

```hcl
# Two providers: default region for most resources, home region for
# ZPR/security-attribute resources, which are CREATE/UPDATE/DELETE-in-
# home-region-only — confirmed by a real 405 MethodNotAllowed the first
# time oci_zpr_configuration ran against a non-home region.
provider "oci" {
  region = var.region
}
provider "oci" {
  alias  = "home_region"
  region = var.home_region
}

# 1. Tenancy onboarding (root compartment, one-time, tenancy-wide)
resource "oci_zpr_configuration" "tenancy_onboarding" {
  provider       = oci.home_region
  compartment_id = var.tenancy_ocid
  zpr_status     = "ENABLED"
}

# 2. Custom security-attribute namespace (analog of oci_identity_tag_namespace)
resource "oci_security_attribute_security_attribute_namespace" "zpr_lab_ns" {
  provider       = oci.home_region
  compartment_id = var.tenancy_ocid
  name           = "ZprLabRole"
  description    = "ZPR lab: classifies compute instances by their SSH trust role."
}

# 3. The attribute itself, ENUM-validated
resource "oci_security_attribute_security_attribute" "ssh_role" {
  provider                         = oci.home_region
  security_attribute_namespace_id  = oci_security_attribute_security_attribute_namespace.zpr_lab_ns.id
  name                              = "SshRole"
  description                       = "trusted-source (may initiate SSH) or ssh-target (accepts SSH only from trusted-source)."
  validator {
    validator_type = "ENUM"
    values          = ["trusted-source", "ssh-target"]
  }
}

# 4. The policy — real ZPR Policy Language, verified against Oracle's docs
resource "oci_zpr_zpr_policy" "ssh_lockdown" {
  provider       = oci.home_region
  compartment_id = var.tenancy_ocid  # tenancy root, not sandbox — see bug list below
  name           = "zpr-lab-ssh-policy"
  description    = "Allow SSH from trusted-source to ssh-target only, independent of NSG/security-list state."
  statements = [
    "in ZprLabRole.Network:zpr-lab-vcn VCN allow ZprLabRole.SshRole:trusted-source endpoints to connect to ZprLabRole.SshRole:ssh-target endpoints with protocol='tcp/22'"
  ]
  depends_on = [oci_zpr_configuration.tenancy_onboarding]
}
```

VM-01 and VM-02 carry the attribute directly as a `security_attributes` map on the instance resource (not inside `create_vnic_details` — the OCI API rejects `security_attributes` supplied in both places on one launch request):

```hcl
security_attributes = {
  "ZprLabRole.SshRole.value" = "trusted-source"  # VM-01 ("ssh-target" on VM-02)
  "ZprLabRole.SshRole.mode"  = "enforce"
}
```

- [x] `oci_zpr_configuration` onboarded ZPR at the tenancy root — live
- [x] `oci_security_attribute_security_attribute_namespace` + `oci_security_attribute_security_attribute` define a custom, tenancy-owned classification (not Oracle's sample `Oracle-DataSecurity-ZPR` namespace) — live
- [x] Both instances tagged via `security_attributes` on the top-level instance resource, `mode = enforce` — live
- [x] `oci_zpr_zpr_policy` references the tagged attribute pair, scoped to `tcp/22` — live
- [ ] A second attribute (`ZprLabRole.Network`) was defined to tag the VCN itself for the policy's `in <attr> VCN` location clause — **the VCN tagging step never succeeded; see the open issue below.** The policy statement above references a VCN tag that does not actually exist on the VCN.

### A4. Five real bugs found via live `terraform apply` — not caught by `validate`

Every one of these was discovered by an actual `400`/`404`/`405` from the live OCI API, not by reading documentation more carefully in advance. `terraform validate` and even `terraform plan` (which only checks provider-side schema, not full semantic/API validity) passed cleanly on every broken version below — only `apply` surfaced them.

| # | Bug | Real error | Fix |
|---|---|---|---|
| 1 | Invented ZPR Policy Language grammar (`endpoint type='compute' from ... to ... allow`) doesn't exist | `400 InvalidParameter: "The policy contains invalid statements"` | Rewrote to the real grammar, verified against Oracle's official Policy Syntax/Examples docs: `in <attr> VCN allow <attr> endpoints to connect to <attr> endpoints with protocol='tcp/PORT'` |
| 2 | Attribute references used `namespace.key.value` (all dots) | Same "invalid statements" 400 as #1 — this was a second, independent bug in the same string | Corrected to `namespace.key:value` (dot then **colon**) — confirmed against Oracle's docs; this is a different separator than the `.value`/`.mode` map-key format used when *tagging a resource*, which genuinely does use all dots |
| 3 | `oci_zpr_configuration` / `oci_security_attribute_security_attribute_namespace` run against the default region (`us-phoenix-1`) | `405 MethodNotAllowed: "CREATE, UPDATE, and DELETE operations should be executed in home region IAD"` / `404 NotAuthorizedOrNotFound` | Added a `home_region` provider alias (`us-ashburn-1`) and applied it to every ZPR/security-attribute resource |
| 4 | `security_attributes` map only included `.value`, not `.mode` | `400 Bad Request: "Security Attribute value is missing a required key (Optional[mode])"` | Added `.mode = "enforce"` alongside `.value` on both instances |
| 5 | `oci_zpr_zpr_policy.compartment_id` was set to `sandbox` (the working compartment) | `400 InvalidParameter: "Invalid compartmentId"` | Changed to `var.tenancy_ocid` — ZPR policies, like ZPR onboarding, are tenancy-root-scoped |
| 6 | NSG rule source used a bare IP, not a CIDR (see A2) | `400 InvalidParameter: "CIDR ... unable to parse"` | Appended `/32` |

**A missing IAM policy was also required and is not a bug in this stack's HCL:** the applying identity (in `Administrators`, with `manage all-resources in tenancy`) got a real `400 InvalidParameter: "No permissions found"` trying `security-attribute-namespace`/`security-attribute` as policy resource-types — neither exists. The correct, Oracle-documented resource-type is the singular `security-attribute-namespace`, which also covers attribute CRUD (there is no separate `security-attribute` policy resource-type at all). A new policy was created:
```
Allow group Administrators to manage security-attribute-namespace in tenancy
Allow group Administrators to manage zpr-configuration in tenancy
Allow group Administrators to manage zpr-policy in tenancy
```
Even after this policy was confirmed active, the next `apply` attempt still failed with the same 404 for several minutes — a real, observed IAM propagation delay, consistent with [[OCI propagation delays]] and the home-region IAM lag already documented in Note 5. Waiting resolved it without further changes.

### A5. Live proof ZPR actually blocks traffic — the core experiment

With the full stack applied and both instances' `SshRole` attribute in `mode = enforce`, the actual test:

**Observed: SSH was completely blocked on both VMs, at the transport level, not just authentication.**
- `nc -zv <ip> 22` succeeded instantly on both VM-01 and VM-02 — the TCP three-way handshake completes.
- An actual SSH client (`ssh -vvv`) got past `Connection established` and sent its version string, then hung and timed out during **banner exchange** — the server never sent anything back.
- A raw `nc` probe confirmed this precisely: the server sent **zero bytes** after the TCP handshake, not a malformed banner, not a delayed one — nothing.
- A known-good control instance from a completely different lab stack (`lab-mymagnet-stack`, different VCN) was tested from the same laptop, same network path, at the same time: it produced an immediate, correct SSH banner exchange and a clean `Permission denied (publickey)` response. This ruled out a local network/client-side cause and isolated the block to `lab-zpr-stack`'s two instances specifically.

**Root cause, confirmed by a controlled before/after test:** VM-01's `SshRole` attribute was cleared via `oci compute instance update --security-attributes '{}'` (a live, deliberate probe, not a config change). The moment that update completed (`security-attributes-state: STABLE`, `security-attributes: {}`), SSH to VM-01 **immediately** worked — full banner exchange, reached real password/publickey authentication (`Permission denied (publickey...)`, an ordinary auth-level rejection, not a network block). VM-02, whose attribute was left untouched, remained blocked throughout, confirming attribute state is applied per-resource, not shared or cross-contaminated.

**This is the single most important finding of this lab:** ZPR's default-deny in `enforce` mode blocks **all** traffic to a tagged resource that isn't explicitly authorized by a matching policy — independent of, and with total priority over, whatever the NSG or security list allow. VM-01 had no ZPR policy authorizing "the internet" (or "my laptop") to reach it at all — only "trusted-source → ssh-target" was ever authorized, which describes VM-01 as a *source*, not a *destination*. The security list explicitly allows `0.0.0.0/0:22` into this subnet, and the NSG doesn't even apply to VM-01 — none of that mattered. This is the CarCo/Science-App lesson (Note 5) made completely concrete: ZPR enforcement doesn't consult NSGs or security lists at all; it's an entirely separate, independent gate that both must be satisfied simultaneously.

**Confirmed authoritatively after the fact — the Console's own "Enable ZPR"
dialog states this exact enforcement order directly, not just as an
inference from this lab's test:** *"For resources with security attributes,
ZPR policy is evaluated first. If ZPR policy permits communication, then
other controls are evaluated in a layered approach. If ZPR policy doesn't
allow communication, the request is dropped."* This also confirms the
default namespace name enabling ZPR creates tenancy-wide — `oracle-zpr` —
distinct from this lab's own custom `ZprLabRole` namespace (both are valid;
a tenancy isn't limited to the default). And it directly explains why
untagged resources elsewhere in the tenancy (every other lab stack) were
completely unaffected by `oci_zpr_configuration` being enabled: *"Enabling
ZPR won't affect communication between resources without security
attributes. ZPR policy is only enforced on resources with security
attributes."*

**State was restored afterward** — the manual CLI probe was reverted via `terraform apply` (matching declared config exactly, confirmed by a subsequent zero-diff `terraform plan`), so the stack's real state is: both instances back in `SshRole = ..., mode = enforce`, fully ZPR-locked, exactly as declared in `main.tf`.

**Official policy syntax, straight from the Console's own policy builder**
(Security → Zero Trust Packet Routing → Policies → Add policy statements),
worth checking against the statement this lab actually applied:

```
in vcn-network:db VCN allow db-client:app1 endpoints to connect to db-server:app1 endpoints

in vcn-network:db VCN allow app:front-end endpoints with protocol = 'tcp/999-11199' to connect to app:back-end endpoints

in vcn-network:db VCN allow app:front-end endpoints to connect to '192.168.1.1/16'
```

**A real discrepancy worth flagging, not yet resolved:** this lab's applied
statement put `with protocol='tcp/22'` at the very end, *after* the
destination endpoints:
```
in ZprLabRole.Network:zpr-lab-vcn VCN allow ZprLabRole.SshRole:trusted-source endpoints to connect to ZprLabRole.SshRole:ssh-target endpoints with protocol='tcp/22'
```
Oracle's own second example places `with protocol = ...` **between** the
source endpoints and `to connect to`:
`app:front-end endpoints **with protocol = 'tcp/999-11199'** to connect to app:back-end endpoints`.
This lab's version was accepted by the live API (the policy applied
successfully), so either both placements are valid ZPR Policy Language, or
the API is more permissive than the documented/Console-generated
convention. Not fully resolved — worth retesting with the clause moved to
match the official placement if this stack is revisited.

Also notable from these examples: protocol supports a **port range**
(`'tcp/999-11199'`), not just a single port (this lab only exercised
`'tcp/22'`), and a ZPR statement can mix a tagged endpoint on one side with
a **plain CIDR** (`'192.168.1.1/16'`) on the other — attribute-to-attribute
isn't the only supported shape.

- [x] `terraform apply`: fully applied — VCN, subnet, security list, NSG, NSG rule, both instances, ZPR configuration, namespace, attribute, and policy are all live
- [x] Live proof that ZPR `enforce` mode blocks traffic independent of NSG/security-list state (A5 above)
- [x] Live proof that clearing the security attribute immediately restores normal connectivity
- [ ] The VM-01 → VM-02 SSH test itself (the scenario's actual end goal) was **not completed** — getting a real shell on either instance hit a separate, unrelated SSH-key/cloud-init issue (correct key fingerprint confirmed matching, but `Permission denied` persisted after the ZPR block was lifted). Not investigated further since the core ZPR question was already answered by A5.

---

## Known open issue: VCN-level `security_attributes` — unresolved

**Every attempt to tag the VCN itself with a security attribute (for the ZPR policy's `in <attr> VCN` location clause) failed with the same error, across every variation tried:**
- Setting it at `oci_core_vcn` creation time: `400 InvalidParameter: "Invalid tags"`
- Setting it via a Terraform-driven update after creation: same error
- Retrying against the home-region provider explicitly: same error
- Retrying with `mode = "audit"` instead of `"enforce"`: same error
- A direct CLI probe (`oci network vnic update --security-attributes '{}'`) revealed a related, more specific constraint: **once `security_attributes` is set at the instance level, `UpdateVnic` refuses to touch that VNIC's attributes at all** (`"VNICs cannot have Security Attributes applied if they are already applied to the Compute Instance"`) — real, useful information, but not the VCN-tagging bug itself, which is a `core_vcn` resource issue, not a VNIC one.
- A separate, definitive constraint was also found on `oci_core_instance`: attempting to switch an already-`enforce` attribute to `audit` via `UpdateInstance` returns `400 InvalidParameter: "Failed to validate tags: zpr tag value must be 'enforce' mode"` — meaning once an attribute is enforced, it may not be relaxed to audit via this path at all (or this specific ENUM/namespace was defined in a way that mandates enforce; not fully isolated).

**Practical consequence:** the ZPR policy's `in ZprLabRole.Network:zpr-lab-vcn VCN` location clause currently has nothing to match, since the VCN was never successfully tagged. The policy exists and is syntactically valid (confirmed — it applied cleanly once the grammar bugs above were fixed), but its location scope cannot resolve. Given A5 already proved `enforce` mode blocks all unauthorized traffic regardless of policy completeness, this open issue doesn't undermine the lab's core finding — it does mean the *specific* "VM-01 may reach VM-02" authorization was never actually confirmed to succeed (only the *deny* side was proven).

**Follow-up for a future session:** file this as a genuine candidate for an Oracle support ticket or a closer read of `UpdateVcn`'s exact required payload shape (possibly the API expects a different structure for VCN-level attributes than the Terraform provider currently sends) — this is a real, reproducible gap between the documented capability (`oci_core_vcn` supports `security_attributes` as a top-level argument, per the provider's own docs) and what the live API accepted in every variation tried here.

## Recall / design exercises

- [ ] Explain why `terraform validate` and even a clean `terraform plan` passed on every one of the six bugs in A4's table. What category of error do these commands catch, and what category do they not catch? Where else in these labs has a similar "the tool didn't error, but it was still wrong" pattern shown up (see Lab 4's guest-OS-firewall finding)?
- [ ] A teammate proposes tagging VM-01 and VM-02 by putting `security_attributes` in both the top-level instance resource *and* `create_vnic_details` "to be safe." What actually happens, and why?
- [ ] Compare this lab's NSG rule (A2) against the ZPR policy (A3): both restrict SSH to VM-01 only. This lab proved ZPR's *deny* side works even without a network-layer control agreeing — what would you need to test to prove the *allow* side works the same way?
- [ ] Explain why `oci_zpr_configuration` and `oci_zpr_zpr_policy` are both scoped to the tenancy root and not to `var.compartment_ocid` the way most other resources in this stack are. What real-world teardown mistake does that scoping guard against?
- [ ] A5's live test found that clearing a security attribute via `UpdateInstance` succeeds, but `UpdateVnic` refuses once an instance-level attribute exists, and switching `enforce`→`audit` on an existing attribute is rejected outright. Given these three facts, describe the actual, supported lifecycle for changing a resource's ZPR posture over time.
- [ ] This lab's ZPR policy is scoped to `type='compute'` and `tcp/22`. Sketch the equivalent policy shape for the CarCo Database scenario in Note 5 (`apps:tele-app` → `db:tele-db`, `tcp/1521`) — what changes, and what stays structurally identical?
- [ ] A scenario states "the security list and NSG both allow this traffic, so it should reach its destination." Using A5's finding, explain why this statement is incomplete for any ZPR-tagged resource, and what additional fact must be verified before concluding traffic will actually flow.

## Official references

- [Zero Trust Packet Routing Overview](https://docs.oracle.com/en-us/iaas/Content/zero-trust-packet-routing/overview.htm)
- [ZPR Policy Syntax](https://docs.oracle.com/en-us/iaas/Content/zero-trust-packet-routing/zpr-policy-syntax.htm)
- [ZPR Policy Examples](https://docs.oracle.com/en-us/iaas/Content/zero-trust-packet-routing/zpr-policy-examples.htm)
- [Managing Security Attributes](https://docs.oracle.com/en-us/iaas/Content/zero-trust-packet-routing/managing-security-attributes.htm)
- [Zero Trust Packet Routing IAM Policies](https://docs.oracle.com/en-us/iaas/Content/zero-trust-packet-routing/policy-reference.htm)
- [ZPR ZPR Policy — Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/zpr_zpr_policy)
- [ZPR Configuration — Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/zpr_configuration)
- [Security Attribute Namespace — Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/security_attribute_security_attribute_namespace)
- [Network Security Groups](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/networksecuritygroups.htm)

#OCI
