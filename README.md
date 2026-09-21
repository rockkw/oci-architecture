# OCI Architect Professional — Study Notes

Working notes, hands-on labs, and Terraform for the **OCI Architect Professional (1Z0-997-26)** certification. This is an active study workspace, not a finished guide — expect gaps, flagged uncertainties, and in-progress sections throughout.

Coming from AWS (SAA-C03), so a recurring thread across these notes is calling out where the AWS→OCI analogy holds and where it breaks.

## How this repo is organized

- **Numbered service notes** (`1. DevOps...`, `5. Security...`, `9. Networking...`, etc.) — one file per exam domain area, covering OCI concepts with citations back to MyLearn course material, official docs, and this repo's own hands-on lab results.
- **`AWS to OCI Exceptions.md`** — not a full service-mapping table, but specifically the places where the AWS→OCI analogy breaks down or diverges in a non-obvious way (e.g. OCI compartments have no AWS equivalent, dynamic groups vs. AssumeRole, stateful/stateless as a per-rule property instead of a per-construct one).
- **`Lab 1`–`Lab 5` notes** — write-ups of specific hands-on exercises (IAM policies, HA/DR design, Vault/Cloud Guard/Security Zones, Zero Trust Packet Routing), each cross-linked to the relevant service note and Terraform stack.
- **`terraform/`** — a progression of small, independent Terraform stacks (see `terraform/LABS.md`) used to actually provision and verify what the course covers, rather than taking documentation claims at face value. Real applied results, real bugs found and fixed, and honestly documented when something doesn't work yet.
- **`MyLearn Skill Check Questions.md`** — every skill check actually taken, with full question text, the answer selected, whether it needed correcting before submitting, and the reasoning tying it back to the relevant note.
- **`Active OCI Architect Professional Certification Plan — 1Z0-997-26.md`** — the four-week study plan this whole repo is organized around, including a running "Top 10 items to review" list populated from real skill-check misses (not guessed weak spots).

## Why the Terraform labs matter here

A lot of these notes don't just restate what a MyLearn slide says — they get verified (or corrected) against a real tenancy. Several genuinely non-obvious findings only surfaced this way, for example:

- OCI Certificates' `timeOfValidityNotAfter` silently requires millisecond precision in its RFC3339 timestamp — undocumented, and the API's own error message never names the actual problem.
- A VNIC with `assign_public_ip = false` on an Internet-Gateway-routed subnet has **zero egress**, not degraded egress — a real outage traced back to this in `lab-mymagnet-stack`.
- `oci_core_vtap` rejects `is_vtap_enabled = true` at creation; it must be created disabled, then enabled in a second apply.

See `terraform/LABS.md` for the full history, including a couple of issues that are still open and unresolved rather than papered over.

## Status

This is a living set of notes updated as the certification prep progresses — see the certification plan file for the current week and the running review list. Not all Terraform stacks in this repo are currently applied; check `terraform/LABS.md` for what's live versus design-only.
