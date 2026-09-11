# OCI Landing Zone — What It Is and What It Provisions

#7_mystudy #OCI  
**Context: discovered mid-Lab 4.** Cloud Guard turned out to already be enabled tenancy-wide with no lab having done it — traced to this tenancy's `rocklz-*` compartment naming (`rocklz-app-cmp`, `rocklz-database-cmp`, `rocklz-network-cmp`, `rocklz-security-cmp`, `rocklz-top-cmp`), which matches Oracle's official Landing Zone reference architecture almost exactly. This note documents what that architecture actually is and does, since it explains a lot of the pre-existing tenancy state these labs have been discovering piecemeal.

## What a Landing Zone actually is

A **Landing Zone** is Oracle's name for a Terraform-based reference architecture that provisions a secure, compliant baseline tenancy structure — compartments, IAM groups/policies, networking, and security services — all at once, rather than an architect building each piece manually. Oracle publishes several variants:
- **Self-Service / CIS Landing Zone** — compliant with the CIS OCI Foundations Benchmark, a widely-used industry security baseline
- **Enterprise Landing Zone (v1/v2)** — a larger-scale variant with multi-business-unit structure and additional operational layers (budgets, notification topics per team)

Both are delivered as Terraform modules — this is itself a direct, concrete example of Infrastructure as Code at the tenancy-bootstrapping level, one layer above anything covered in Note 8.1's hands-on labs.

## What it provisions — the compartment structure

The Landing Zone's core output is a designed compartment hierarchy, each with its own IAM group holding exactly the permissions needed for that compartment's purpose (least privilege applied at the tenancy-design level, not just per-resource). The pattern observed in this tenancy:
- A **network compartment** (`rocklz-network-cmp`) — VCNs, subnets, gateways, isolated from application logic
- A **security compartment** (`rocklz-security-cmp`) — Vault, Bastion, logging/audit infrastructure
- An **application compartment** (`rocklz-app-cmp`) — workload compute/PaaS resources
- A **database compartment** (`rocklz-database-cmp`) — database services, separated from the app tier
- A **top-level/parent compartment** (`rocklz-top-cmp`) — the landing zone's own root, everything else nests under it

This is the same segregation-of-duties principle from Note 5's IAM section (compartments limit blast radius, policies grant narrowly) applied at the scale of an entire tenancy design, not just a single lab's resource.

## What it provisions — security services enabled by default

Per Oracle's own documentation, a Landing Zone deployment (CIS variant specifically) provisions and enables, out of the box:
- **Cloud Guard** — a target at the root/parent compartment, with Oracle-managed Configuration and Activity detector recipes and a Responder recipe already attached. This is confirmed and documented behavior: *"OCI Landing Zone enables Cloud Guard monitoring in a tenancy by default... it provisions a Cloud Guard target for the root compartment, attaching the out-of-box Configuration and Activity detector recipes and Responder recipe."* Explains exactly what was found live in this tenancy — Cloud Guard already on, security score "Excellent," before any lab touched it.
- **Vault** — for encryption key management, placed in the security compartment
- **Bastion** — for controlled administrative access without exposing SSH broadly
- **Logging and Service Connector Hub** — centralized log routing
- **Vulnerability Scanning** — host and container image scanning

## What this means for interpreting these labs

Several things that looked like open questions in earlier labs are actually **inherited landing-zone decisions**, not blank slates:
- Being a member of **Administrators** with tenancy-wide `manage all-resources` — worth checking whether the landing zone's IAM design actually intended broader use of scoped compartment-admin groups instead, which the labs haven't been exercising
- **Cloud Guard's current scope and responder mode** (Lab 4, B1) — verified via direct investigation: `sandbox` **is** covered by a root-scoped target inherited from this setup, despite an initial Console filtering quirk that briefly suggested otherwise (filtering by a target's home compartment is not the same as checking its monitored hierarchy — see Lab 4 for the full walkthrough)
- The **`sandbox` compartment** used throughout Labs 1-4 is *not* one of the landing zone's own structural compartments (`rocklz-*`) — it's a separate, deliberately-isolated compartment for lab work, which is exactly the right call: it means none of this experimentation touches the landing zone's actual designed structure

## Confirmed via Audit log: the Landing Zone created this target

The "two separate explanations" theory below was a reasonable hypothesis at the time but turned out to be wrong — checked directly via **Identity & Security → Audit**, filtering to the target's creation timestamp (`Apr 17, 2025, 14:31:17 UTC`): the `CreateCloudGuardTarget` event's calling principal traces back to the **Landing Zone deployment itself**, not a separate Oracle-internal employee-governance mechanism. The "Internal Security Posture" naming and the presence of proprietary-looking tool checks (Griffin agent, Tartan patching) turned out to be part of what this specific Landing Zone variant provisions, not evidence of a second, unrelated source layered on top.

**The methodological lesson still holds even though the specific theory was wrong:** checking an object's own metadata (a target's description) was the right instinct, but the audit log — showing the actual calling principal for the creation event — is stronger evidence than either compartment naming or the target's own description text. When those two forms of circumstantial evidence disagree with what the audit trail actually shows, trust the audit trail.

## What was investigated before reaching that answer (kept for the record)

Investigating the root-scoped Cloud Guard target's actual detector rules (Lab 4) surfaced something worth separating out rather than folding into one story. The target's own description reads: *"Cloud Guard created target for monitoring the security posture of **internal tenancies**."* Its attached Instance Security recipe includes rules for tools like **Griffin agent** and **Tartan patching** — names that don't appear in any public Oracle documentation, strongly suggesting they're **Oracle-internal** security tooling, not something a normal external customer tenancy would ever have applied to it.

Combined with this account being an Oracle employee identity (`rock.whitney@oracle.com`), the more precise picture is likely **two separate things layered on top of each other**, not one:
1. **A customer-facing Landing Zone deployment** — explains the `rocklz-*` compartment structure (network/security/app/database segregation) described above, matching Oracle's publicly documented reference architecture
2. **Oracle-internal corporate governance, applied automatically to Oracle employee-owned tenancies** — explains the "Internal Security Posture Target" specifically, including proprietary internal tooling checks that have nothing to do with the public Landing Zone template

**Why this distinction matters for the exam and for reading this tenancy accurately:** don't assume everything unexplained in a real tenancy traces back to one tidy cause. A `rocklz`-named compartment structure is genuinely explained by the public Landing Zone architecture — but not every pre-existing Cloud Guard target necessarily is. Some tenancy state can come from a completely different source (here, employer-applied internal governance) that happens to coexist with the customer-facing structure. When auditing an unfamiliar tenancy, check what each individual piece's own metadata says (a target's description field, in this case) rather than attributing every discovery to the first explanation that fit.

## Recall / design exercises

- [ ] Explain why a Landing Zone's compartment-per-function design (network, security, app, database) is described as "least privilege at the tenancy-design level" — what would the alternative (one flat compartment) actually cost in blast-radius terms?
- [ ] A Landing Zone deployment provisions Cloud Guard automatically. Why might a security review still need to check its target scope and responder mode rather than assuming the default is correct for every workload added afterward?
- [ ] This tenancy's `sandbox` compartment was created outside the landing zone's own compartment structure. Explain why that's a deliberate, correct choice for lab/study work rather than a gap in the landing zone's design.
- [ ] Compare the CIS Landing Zone's compartment/IAM/Cloud Guard baseline to a single dynamic-group-and-policy pair from Lab 3. What's the relationship between "designing one policy correctly" and "designing an entire tenancy's IAM structure correctly" — same principles, different scale?
- [ ] Explain why the audit log's calling-principal record is stronger evidence for a tenancy object's origin than either its compartment naming convention or its own description text — and why this investigation initially favored the wrong theory before checking it.

## Official references

- [Deploy a Secure Landing Zone That Meets the CIS Foundations Benchmark](https://docs.oracle.com/en/solutions/cis-oci-benchmark/index.html)
- [Self-Service Landing Zone](https://docs.oracle.com/en-us/iaas/Content/cloud-adoption-framework/cis-benchmark-landing-zone.htm)
- [Cloud Guard Support in CIS OCI Landing Zone](https://www.ateam-oracle.com/cloud-guard-support-in-cis-oci-landing-zone) — source for the "enabled by default" Cloud Guard behavior confirmed live in this tenancy
- [Oracle Enterprise Landing Zone Architecture](https://docs.oracle.com/en/solutions/deploy-baseline-lz/img_text/elz-security.html)
- [Introducing the New Standardized OCI Landing Zones Framework](https://blogs.oracle.com/cloud-infrastructure/new-standardized-oci-landing-zones-framework)
