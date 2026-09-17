# Lab 5 - OCI Architect Pro Exam - Zero Trust Packet Routing

#7_mystudy #OCI  
**Plan item:** extend Week 2's network-security work (Module: Network Security) with hands-on Zero Trust Packet Routing (ZPR) — provision the MyLearn "Scenario" lab (VM-01 → VM-02 SSH lockdown) via Terraform, not just diagram it.

**Companion references:** [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]] for the full ZPR concept writeup (Science App and CarCo MyLearn scenarios, the four-pillar pitch, policy syntax) and [[terraform/LABS.md]] for the `lab-zpr-stack` build this lab documents. [[Lab 4 - OCI Architect Pro Exam - Vault, Guard, Zones, Logging, Network Boundary]] for the NSG/security-list layer this lab's ZPR policy sits on top of.

**Split approach, and why:** unlike Lab 4's Cloud Guard/Security Zones/WAF split, this lab's entire scope was buildable and safe to dry-run: no tenancy-wide singleton risk beyond `oci_zpr_configuration` itself (ZPR onboarding is additive — it does not retroactively restrict existing resources the way a Security Zone recipe does), and no meaningful cost (2 small ARM Compute instances, planned but never applied). Everything below is **Part A** in Lab 4's terms — there is no diagram-only Part B here.

---

## Part A — Build for real (Terraform, dry-run)

### A1. Reproduce the MyLearn scenario topology

MyLearn's "OCI ZPR" scenario: one VCN, one public subnet, two Compute instances (VM-01, VM-02), and a stated goal — "Restrict SSH access to VM-02 from the internet" / "Allow SSH access to VM-02 only from VM-01." The starting security list is deliberately over-permissive: stateful ingress TCP/22 from `0.0.0.0/0`.

**Terraform (`terraform/lab-zpr-stack/main.tf`):** VCN (`10.0.0.0/16`), IGW, public route table, a security list matching the scenario's exact starting rule (TCP/22 from `0.0.0.0/0`, all egress), one public subnet, two `VM.Standard.A1.Flex` instances.

- [x] VCN, IGW, route table, security list, subnet defined
- [x] VM-01 and VM-02 defined on the same public subnet

### A2. Network-layer fix first — the scenario's own stated remediation

Before touching ZPR, the scenario asks for a conventional fix: an NSG on VM-02 allowing SSH only from VM-01's address, not the internet at large. Built as its own resource, referencing VM-01's private IP directly (a real Terraform dependency, not a hardcoded address):

```hcl
resource "oci_core_network_security_group_security_rule" "vm02_allow_ssh_from_vm01" {
  network_security_group_id = oci_core_network_security_group.vm02_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_instance.vm_01.private_ip
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}
```

**Design note carried over from Note 5's ZPR section:** this NSG rule is exactly the kind of hand-authored, address-based rule that MyLearn's own NSG-bug slide showed going wrong — a single mistyped CIDR digit slipped past a two-person authoring/approval process undetected. This lab's NSG rule references `oci_core_instance.vm_01.private_ip` as a live Terraform attribute rather than a typed literal specifically to avoid that exact failure mode, though in a hand-typed real-world NSG rule (not a Terraform-managed one) that protection doesn't exist — the address still has to be transcribed correctly by a human.

- [x] NSG created, scoped to VM-02
- [x] Ingress rule restricts SSH to VM-01's private IP only (not internet-wide)

### A3. ZPR layer — the part that holds even if A2's NSG is later misconfigured

This is the lab's actual point: provision a ZPR policy that enforces the same "VM-01 → VM-02 only" intent independent of whatever the NSG or security list say, per Note 5's CarCo lesson ("networking changes can't invalidate ZPR security policies").

**Four ZPR resources, in dependency order:**

```hcl
# 1. Tenancy onboarding (root compartment, one-time, tenancy-wide)
resource "oci_zpr_configuration" "tenancy_onboarding" {
  compartment_id = var.tenancy_ocid
  zpr_status     = "ENABLED"
}

# 2. Custom security-attribute namespace (analog of oci_identity_tag_namespace)
resource "oci_security_attribute_security_attribute_namespace" "zpr_lab_ns" {
  compartment_id = var.tenancy_ocid
  name           = "ZprLabRole"
  description    = "ZPR lab: classifies compute instances by their SSH trust role."
}

# 3. The attribute itself, ENUM-validated
resource "oci_security_attribute_security_attribute" "ssh_role" {
  security_attribute_namespace_id = oci_security_attribute_security_attribute_namespace.zpr_lab_ns.id
  name                             = "SshRole"
  description                      = "trusted-source (may initiate SSH) or ssh-target (accepts SSH only from trusted-source)."
  validator {
    validator_type = "ENUM"
    values          = ["trusted-source", "ssh-target"]
  }
}

# 4. The policy — ties tagged endpoints together
resource "oci_zpr_zpr_policy" "ssh_lockdown" {
  compartment_id = var.compartment_ocid
  name           = "zpr-lab-ssh-policy"
  description    = "Allow SSH from trusted-source to ssh-target only, independent of NSG/security-list state."
  statements = [
    "endpoint type='compute' from security_attribute='ZprLabRole.SshRole.trusted-source' to security_attribute='ZprLabRole.SshRole.ssh-target' with protocol='tcp/22' allow"
  ]
  depends_on = [oci_zpr_configuration.tenancy_onboarding]
}
```

VM-01 and VM-02 carry the attribute directly as a `security_attributes` map on the instance resource (not inside `create_vnic_details` — the OCI API rejects `security_attributes` supplied in both places on one launch request):

```hcl
security_attributes = {
  "ZprLabRole.SshRole.value" = "trusted-source"  # VM-01
  # or "ssh-target" on VM-02
}
```

- [x] `oci_zpr_configuration` onboards ZPR at the tenancy root
- [x] `oci_security_attribute_security_attribute_namespace` + `oci_security_attribute_security_attribute` define a custom, tenancy-owned classification (not Oracle's sample `Oracle-DataSecurity-ZPR` namespace)
- [x] Both instances tagged via `security_attributes` on the top-level instance resource
- [x] `oci_zpr_zpr_policy` references the tagged attribute pair, scoped to `tcp/22`

### A4. Verification — and a real bug found along the way

**Test 1 — `terraform validate`:** passed on the *first* draft of the ZPR resources, which used unnamespaced, freeform strings guessed directly from MyLearn's UI-level tag shorthand (`#app:science`-style syntax) — e.g. `security_attribute='vm:trusted-source'`. This is the lab's most important finding: **`terraform validate` only checks HCL syntax, not whether a string argument matches the real OCI API's expected format.** A schema-shaped-but-semantically-wrong config passes validate cleanly and would only fail at `apply`, against a real API error.

**Test 2 — corrected against the provider's own doc source:** re-checked the `oracle/oci` provider's actual `core_instance.html.markdown` doc, which confirmed `security_attributes` values are namespaced exactly like defined tags: `"<Namespace>.<AttributeName>.value" = "<value>"`. This also surfaced a structural fact the first draft missed entirely — the namespace and attribute are **real, separately-provisioned resources** (`oci_security_attribute_security_attribute_namespace` / `oci_security_attribute_security_attribute`), not implicit strings conjured by a policy statement.

**Test 3 — `terraform plan` against the live tenant (`sandbox` compartment, real tenancy OCID, no placeholders):**

```
Plan: 13 to add, 0 to change, 0 to destroy.
```

All 13 resources — VCN, IGW, route table, security list, subnet, NSG, NSG rule, 2 instances, ZPR configuration, namespace, attribute, and policy — planned cleanly with real values. **Not applied** — this lab is dry-run only, per the same cost/reversibility judgment call as Lab 4's Part A/B split, just landing entirely on the "build for real" side since nothing here is tenancy-risky or costly to leave running.

- [x] `terraform validate`: passed (but see the caveat above — passing validate is not proof of correctness)
- [x] `terraform plan`: 13 to add, 0 errors, against real tenancy/compartment OCIDs
- [ ] `terraform apply`: not run — see "Known unresolved question" below before attempting

**The real lesson, worth more than a clean first pass would have been:** the same principle Lab 4 surfaced for NSGs vs. guest-OS firewalls applies here one layer up the stack — a Terraform tool succeeding (`validate`) is not the same guarantee as the underlying cloud API accepting the same input. Two independent checks (schema validity and semantic/API-format validity) both have to pass, and only the second one actually catches a wrong-but-plausible-looking string.

---

## Known unresolved question

The exact complete grammar of ZPR Policy Language (the full enum of valid `mode` values beyond the one documented example, `audit`; whether `with protocol=` is the correct clause name) was not confirmed against Oracle's own ZPR conceptual docs, which returned only high-level summaries on repeated fetch attempts — only the Terraform provider's own argument-level documentation could be verified directly. If `terraform apply` is ever run against `lab-zpr-stack`, the `statements` string is the most likely single point of failure, and the real API error message (not more doc-guessing) should drive any correction.

## Recall / design exercises

- [ ] Explain why `terraform validate` passed on the first (wrong) draft of this lab's ZPR resources. What category of error does `validate` catch, and what category does it not catch? Where else in these labs has a similar "the tool didn't error, but it was still wrong" pattern shown up (see Lab 4's guest-OS-firewall finding)?
- [ ] A teammate proposes tagging VM-01 and VM-02 by putting `security_attributes` in both the top-level instance resource *and* `create_vnic_details` "to be safe." What actually happens, and why?
- [ ] Compare this lab's NSG rule (A2) against the ZPR policy (A3): both restrict SSH to VM-01 only. What specifically survives a network-layer change (re-IP, subnet re-CIDR, security list edit) under ZPR that would break the NSG rule?
- [ ] Explain why `oci_zpr_configuration` is scoped to the tenancy root and not to `var.compartment_ocid` the way every other resource in this stack is. What real-world teardown mistake does that scoping guard against?
- [ ] A security-attribute namespace and its attribute are provisioned as their own Terraform resources, separate from the ZPR policy. Why does that separation matter for a design where multiple unrelated ZPR policies need to reference the same classification (e.g., "trusted-source")?
- [ ] This lab's ZPR policy is scoped to `type='compute'` and `tcp/22`. Sketch the equivalent policy shape for the CarCo Database scenario in Note 5 (`apps:tele-app` → `db:tele-db`, `tcp/1521`) — what changes, and what stays structurally identical?

## Official references

- [Zero Trust Packet Routing Overview](https://docs.oracle.com/en-us/iaas/Content/zero-trust-packet-routing/overview.htm)
- [Managing Security Attributes](https://docs.oracle.com/en-us/iaas/Content/zero-trust-packet-routing/managing-security-attributes.htm)
- [ZPR ZPR Policy — Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/zpr_zpr_policy)
- [ZPR Configuration — Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/zpr_configuration)
- [Security Attribute Namespace — Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/security_attribute_security_attribute_namespace)
- [Network Security Groups](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/networksecuritygroups.htm)

#OCI
