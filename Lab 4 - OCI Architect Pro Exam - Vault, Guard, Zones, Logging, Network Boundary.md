# Lab 4 - OCI Architect Pro Exam - Vault, Guard, Zones, Logging, Network Boundary

#7_mystudy #OCI  
**Plan item:** Configure or diagram Vault, Cloud Guard, Security Zones, logging/audit retention, and a network boundary (NSGs/security lists, WAF or Network Firewall) appropriate to a web workload.

**Companion references:** [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]] for the underlying concepts; [[Lab 1 - OCI Architect Pro Exam]] for the `lab-vcn`/`lab-subnet` this lab attaches to; [[Lab 3 - OCI Architect Pro Exam - IAM Policies]] for the IAM layer this lab's network/data-protection layer sits alongside.

**Split approach, and why:** five services here fall into two very different risk profiles. Vault, NSGs, and logging/audit retention are cheap, reversible, and scoped to `sandbox` — build these for real. Cloud Guard, Security Zones, and WAF/Network Firewall each carry a blast radius or cost profile that makes "diagram and justify" the more honest exercise than "provision casually in a study tenancy":
- **Cloud Guard** is a tenancy-wide singleton — enabling it changes posture monitoring across every compartment, not just `sandbox`.
- **Security Zones** enforces a recipe retroactively against existing resources — the `lab-vcn`/`lab-func-stack` resources from Labs 1-3 weren't built against any security zone recipe and would likely get flagged or blocked from further changes if a zone were applied after the fact.
- **WAF and Network Firewall** both carry ongoing hourly cost for a workload that's a `Hello World` function, not a real web app worth protecting at the edge.

---

## Part A — Configure for real

### A1. Vault + Master Encryption Key

**Console path:**
1. Identity & Security → Vault → **Create Vault**
2. Name: `lab-vault`, Compartment: `sandbox`, Type: Virtual (default; Private/Dedicated is a distinct paid tier, not needed here)
3. Inside the vault → **Create Key**
4. Name: `lab-key`, Protection Mode: Software (HSM-backed FIPS mode is the paid alternative — Note 5's "Vault vs. Dedicated KMS" distinction applies here directly), Algorithm: AES, Length: 256

**Test:** confirm the key shows `Enabled` state, then optionally reference it from a resource that supports customer-managed keys (e.g., enable customer-managed encryption on the `lab-repo` OCIR repository or a new Object Storage bucket) to prove the key is actually usable, not just created.

- [ ] Vault created
- [ ] Key created, state: `_____________________`
- [ ] (Optional) key referenced by a real resource, confirmed working

### A2. NSGs for the web workload — reusing Lab 1's network

Rather than inventing a new scenario, apply Note 9's NSG-based tier-isolation pattern to what already exists: the API Gateway from Lab 1 is the actual "web workload" ingress point in this tenancy.

**Design:** a single NSG scoped to the API Gateway's subnet, allowing only inbound 443 from the internet — demonstrating the network boundary a web workload needs at minimum, even though Lab 1's Gateway is a managed PaaS resource and doesn't sit behind a VNIC the way a Compute instance would.

**Terraform addition (append to a new or existing stack targeting `lab-vcn`):**
```hcl
resource "oci_core_network_security_group" "web_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "web-nsg"
}

resource "oci_core_network_security_group_security_rule" "web_ingress_https" {
  network_security_group_id = oci_core_network_security_group.web_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}
```

**Test:** attach the NSG to a real VNIC-bearing resource (a Compute instance is the clean test case, since API Gateway itself doesn't expose an NSG-attachable VNIC the way Compute does) and confirm 443 reachability while all other ports remain closed by default (no egress rule = default allow-all egress unless explicitly restricted — worth confirming this default rather than assuming).

**Actual results, and a real discovery along the way:**
- Port 80 (nothing permits it anywhere): `TIMEOUT` — silently dropped, the expected signature of a network-layer block
- Port 22 (default security list): `Connected` — expected, security list still has SSH open by default
- Port 443, first attempt: `No route to host` — unexpected. Root cause: the instance's **guest OS firewall (`firewalld`)** only had `ssh` in its allowed services — OCI's NSG and security list both permitted 443, but the guest OS itself never did. Fixed with `sudo firewall-cmd --permanent --add-service=https && sudo firewall-cmd --reload`.
- Port 443, after the firewalld fix: `Connection refused` — this is the correct success signal, not a failure. "Refused" means the packet reached the host and got a fast TCP RST because nothing is listening on 443 (no web server installed) — categorically different from a timeout (blocked) or "no route to host" (a host-level rejection, as seen before the firewalld fix).

**The real lesson, worth more than a clean pass would have been:** OCI's network controls (NSG, security list) and the guest OS's own firewall are two independent, both-must-agree gates — exactly Note 9's stated warning ("OCI network rules do not override guest OS controls"), now verified concretely rather than just read. A design or exam scenario that only reasons about NSGs/security lists and ignores the guest OS layer is incomplete.

- [x] NSG created
- [x] Attached to a test resource, 443 reachability confirmed (after fixing firewalld)
- [x] Confirmed other ports blocked (port 80 timed out as expected)
- [x] Bonus finding: guest OS firewall as a separate, required gate — logged above

### A3. Logging / Audit retention

**Console path:**
1. Governance → **Audit** → confirm Audit is enabled tenancy-wide by default (it is, non-optional — unlike other logging, Audit cannot be disabled) and check the current retention setting
2. Adjust retention if the default (typically 365 days) doesn't match a stated requirement — retention is configurable up to a maximum window Oracle publishes in the Audit service limits
3. Observability & Management → **Logging** → confirm a Log Group exists in `sandbox` (create one if not — `lab-log-group`) and that Lab 1's API Gateway execution logs are flowing into it, since that's already configured from Lab 1's troubleshooting

**Test:** confirm at least one real log entry exists and is queryable via Logging → Search, using the same search that surfaced the `functionBackend.notFoundOrNotAuthorized` error in Lab 1 as proof retention/ingestion is actually working, not just configured.

**Results:** Audit retention period confirmed at 365 days (Oracle's default, no adjustment needed — Console → Governance & Administration → Account Management → Tenancy Details → "Audit retention period days"). Log Group and log flow already proven working throughout Lab 1's entire troubleshooting arc — that log stream is how the `functionBackend.notFoundOrNotAuthorized` errors were diagnosed in the first place, so ingestion/retention was never in doubt by the time this lab reached it.

- [x] Audit retention checked/set: 365 days (default, unchanged)
- [x] Log Group confirmed, entries queryable (proven throughout Lab 1)

---

## Part B — Diagram / design, not provisioned

### B1. Cloud Guard — already enabled, not a hypothetical

**Correction from the original plan:** checking the Console (Cloud Guard → Overview) showed Cloud Guard is **already enabled tenancy-wide** — Security score "Excellent" (100), zero open problems. Cloud Guard is not enabled by default in a new OCI tenancy (Oracle's own docs are explicit: it's *available* to any paid tenancy but requires an explicit enable step — creating the policy, choosing a target and reporting region). The far more likely explanation here: this tenancy's `rocklz-*` compartment structure (`rocklz-app-cmp`, `rocklz-network-cmp`, `rocklz-security-cmp`, etc.) strongly matches Oracle's official **Landing Zone** reference architecture, a Terraform-based quick-start that provisions a security baseline — including enabling Cloud Guard tenancy-wide — as part of its standard setup. So this wasn't a lab decision at all; it predates these labs entirely.

**What this changes about the design exercise:** the question shifts from "should we enable Cloud Guard" to "does its *current* configuration match what this workload actually needs." Checked via Cloud Guard → Targets:

- **Two targets exist, both scoped at the tenancy root** (`rocwyvpy14 (root)`): "Internal Security Posture Target" (Local scope, created Apr 2025 — matches the Landing Zone's own setup timing) and "Assurance Managed Cloud Guard Target" (Governed scope, Locked — likely a separately Oracle-managed governance layer, not investigated further here).
- **Initial false alarm, corrected:** filtering the Targets list by "Compartment: sandbox" returned zero results, which briefly looked like `sandbox` had no Cloud Guard coverage at all. That filter turned out to be filtering by each target's own **home** compartment (where it was created), not by its **monitored** compartment hierarchy. Per Oracle's own docs, a target scoped at root automatically includes every sub-compartment beneath it — including `sandbox` — unless a separate target has explicitly claimed that sub-compartment (none has). Confirmed via the target's Configuration tab: attached detector recipes (e.g., an Instance Security recipe) apply against the root scope, which covers `sandbox` by inheritance.
- **Actual conclusion: no coverage gap.** `sandbox` has been monitored by Cloud Guard the entire time these labs have been running, inherited from the root-level target — this was never a lab decision to make.

**Design conclusion, updated again:** the real deliverable here isn't "should sandbox be covered" (it already is) but recognizing the distinction between a target's **home compartment** (an administrative detail, filterable in the Console) and its **monitored scope** (the actual compartment hierarchy it watches) — conflating the two produces exactly the false "gap" this investigation initially found and then had to walk back.

### B2. Security Zones — design without enabling

**What it would do if enabled:** validate every create/update operation in a protected compartment against a recipe, denying non-compliant operations outright (e.g., blocking public subnet creation).

**Why not applied to `sandbox` as-is:** `lab-subnet` is already public (Lab 1 required it for Functions' OCIR egress). A standard "no public subnets" security zone recipe would immediately conflict with existing, working infrastructure. **Design conclusion:** Security Zones fits a *greenfield* compartment created zone-first, not an existing compartment retrofitted after the fact — worth stating this ordering dependency explicitly, since it's a real design constraint the exam could test ("can Security Zones be applied to an existing non-compliant compartment" — the honest answer is it will flag/block based on the recipe, not silently coexist).

### B3. Network boundary choice: WAF vs. Network Firewall for this web workload

| Factor | WAF | Network Firewall |
|---|---|---|
| Layer | 7 (HTTP/HTTPS inspection) | 3/4 (routed network traffic) |
| Fits API Gateway ingress? | Yes — directly, sits in front of the public endpoint | Not directly — would need to be inserted into a routed path, awkward for a PaaS Gateway endpoint that isn't behind a customer-managed VCN hop |
| Cost profile for this workload | Lower, scoped to the endpoint | Higher, sized for broader routed traffic inspection |
| **Design choice for this workload** | **WAF** | Not selected |

**Justification:** the actual traffic pattern here is HTTP requests hitting a public API Gateway endpoint — exactly WAF's scope (SQLi/XSS/bot/rate-limit protection per Note 5). Network Firewall is the right tool for routed, VCN-internal traffic inspection (e.g., a hub-and-spoke DRG topology with centralized inspection, per Note 9) — a shape this single-Gateway workload doesn't have. **This is the general selection principle to state on the exam**, not just this workload's answer: WAF for public HTTP(S) endpoints, Network Firewall for routed VCN/DRG traffic paths.

---

## Recall / design exercises

- [ ] Explain why the exam distinguishes "connection refused" from "connection timed out" from "no route to host" when reasoning about a failed connectivity test — what does each one rule in or out about where in the stack the block is happening?
- [ ] A teammate's design only lists NSG and security list rules when documenting a web workload's network boundary. What's missing, and what real symptom would surface if that gap went unnoticed until production?

- [ ] Explain why Security Zones enforcement is order-dependent — why does applying a recipe to an already-built, non-compliant compartment behave differently than building a compartment zone-first?
- [ ] A design review asks why Cloud Guard responders are set to notify-only rather than automatic in this environment specifically. Justify using the actual state of the `sandbox` compartment (labs being built/destroyed regularly) as the reasoning, not a generic best-practice statement.
- [ ] Explain the difference between a Cloud Guard target's "home compartment" and its "monitored compartment hierarchy." Why did filtering the Targets list by compartment produce a misleading result, and what would the correct way to check whether a specific compartment is covered actually be?
- [ ] Given the WAF vs. Network Firewall table above, describe a workload shape where the answer would flip — where Network Firewall becomes the right choice and WAF alone would be insufficient.
- [ ] Why does Audit not appear in either "Part A" or "Part B" as a build-or-skip decision — what's different about Audit's default state compared to Cloud Guard or Security Zones?
- [ ] Explain the NSG default-egress behavior confirmed in A2 — why is "no egress rule" not the same as "no egress allowed," and where else in these labs has an equivalent default-allow-unless-restricted pattern already appeared?

## Official references

- [Vault Overview](https://docs.oracle.com/en-us/iaas/Content/KeyManagement/Concepts/keyoverview.htm)
- [Cloud Guard](https://docs.oracle.com/en-us/iaas/Content/cloud-guard/home.htm)
- [Security Zones](https://docs.oracle.com/en-us/iaas/Content/security-zone/home.htm)
- [OCI Audit](https://docs.oracle.com/en-us/iaas/Content/Audit/home.htm)
- [Network Security Groups](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/networksecuritygroups.htm)
- [OCI WAF Policies](https://docs.oracle.com/en-us/iaas/Content/WAF/Policies/waf-policy_management.htm)
