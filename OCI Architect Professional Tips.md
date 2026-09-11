# OCI Architect Professional Tips — 1Z0-997-26

#certs #7_mystudy

**Companion reference:** [OCI_Architect_Professional_CheatSheet.html](OCI_Architect_Professional_CheatSheet.html) — a one-page visual service reference (Compute, Networking, Storage, Database, Security, Governance, Observability, Migration, AI/Multicloud) plus exam snapshot and domain weighting, styled the same way as your AWS SAA-C03 poster.

Unlike your AWS tips file, this isn't a refresh of old notes — it's a first pass, since this is a new cert for you rather than a recert. Treat it as a starting skeleton to add to as you go through labs.

---

## 1. The format is the biggest trap, not the content
This is a **Hands-on Performance Exam (HPE)**: real lab tasks in a live OCI environment, scored per sub-task with partial credit, blended with multiple-choice. If a scenario asks for 9 configuration steps and you complete 7, you get credit for 7 — so **don't skip a hard sub-task to save time**, since partial credit rewards attempting everything over polishing fewer things. This is fundamentally different from AWS's all-or-nothing MCQ scoring and changes your exam-day time strategy: triage by "what can I at least partially complete" rather than "what am I most confident about."

## 2. Where your AWS instincts will mislead you
- **Licensing is tested, and AWS has no equivalent.** BYOL vs. included licensing, RAC, Exadata — these show up in architecture decisions as real cost/compliance constraints, not just trivia. AWS certs never make you reason about vendor licensing this way.
- **Identity domains vs. legacy IAM** — OCI has both a legacy IAM model and a newer "identity domains" layer. Don't assume they're interchangeable; expect scenario questions that hinge on which one a described tenancy is using.
- **Compartments are not the same mental model as AWS accounts/OUs.** Compartments are a logical partition within a single tenancy, not a separate account boundary — policy inheritance and cross-compartment access work differently than AWS Organizations SCPs. Worth explicitly re-deriving rather than assuming your AWS Organizations knowledge transfers.

## 3. Domain-specific gotchas to watch for as you study
- **Data Guard**: know the difference between Maximum Availability, Maximum Performance, and Maximum Protection modes — this is analogous to AWS RDS Multi-AZ sync-vs-async tradeoffs but with three named tiers instead of a binary choice.
- **Autonomous Database Shared vs. Dedicated**: Dedicated (Exadata infrastructure) is the answer whenever a scenario mentions strict isolation, custom maintenance windows, or specific compliance/regulatory requirements — Shared is the default/cost-optimized answer otherwise.
- **FastConnect vs. VPN Connect**: same "private dedicated line vs. IPSec over internet" framing as AWS Direct Connect vs. Site-to-Site VPN — this one instinct probably does transfer cleanly.

## 4. Study approach adjustments vs. your AWS process
- Question banks (WhizLabs-equivalent for OCI) are useful for the MCQ portion only — don't mistake a high practice-test score for lab readiness.
- Build everything in Week 1-3 of the plan in an actual tenancy at least once without following a tutorial verbatim, close to exam conditions, before your final week.
- No personal weak-area baseline exists yet for this exam (unlike your AWS notes going back to 2019/2023) — this file will need real updates after your first practice assessment and again after the actual exam, the way your AWS tips file accumulated corrections over multiple passes.

---

## Open items to fill in as you go
- [ ] Exact current domain weightings (Oracle's public blueprint page, verify directly — not yet confirmed at time of writing)
- [ ] Whether your OCI employee status gives voucher/discount access to the $245 fee or paid Professional course content
- [ ] Post-practice-assessment: which domains are actually your weak spots (can't front-load this one, unlike AWS)
