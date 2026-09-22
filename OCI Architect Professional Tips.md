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

## 4. Recurring exam-question pattern: fabricated-option distractors

**Observed starting with the Autonomous Database skill check retake**:
several MyLearn skill-check questions mix real OCI concepts with
**entirely fabricated options that sound plausible but don't exist**,
rather than just offering real-but-wrong answers. Two distinct flavors
seen so far:

1. **Fabricated services/features** — e.g., "Azure HPC" and "Dedicated
   Exadata infrastructure in AWS" as deployment-option choices (neither
   is a real Autonomous Database deployment option — AD has no native
   Azure/AWS deployment at all), or "Autonomous Blockchain Database" as
   a workload-type choice (not one of the real four: ATP/ADW/AJD/APEX).
2. **Real concepts, wrong scope** — e.g., "Name of superuser" and
   "Network access type" as provisioning inputs (both ARE real
   provisioning-time inputs) offered alongside the three the question
   was actually built around (deployment type, compute model/shape,
   workload type) — correct-sounding but not what's being asked.

**Study implication**: don't pattern-match on "does this sound like a
real OCI term" — verify against the actual closed, finite list of named
options. This is a common Oracle cert-exam style, not unique to this
skill check, so expect it on the real 1Z0-997-26 exam too. See
[[MyLearn Skill Check Questions]] for each flagged instance as it comes
up.

**Five-step prep strategy against this pattern:**
1. **Build "the finite list" for every enumerable OCI concept, and drill
   it as a set, not individual facts.** For anything with a fixed
   number of named options (workload types, deployment options, clone
   types, consumer group tiers, etc.), memorize the *count* first, then
   the names — see the "Finite-lists cheat-sheet" below. If you know
   there are exactly 4, a 5th-sounding option is an instant red flag no
   matter how plausible it sounds.
2. **Treat every "sounds right but I don't specifically remember it"
   answer as a red flag, not a plausible answer.** The trap isn't "is
   this a real thing" — it's "is this one of the *specific* things this
   question is asking about." Ask "which exact named list does this
   question want?" before evaluating options.
3. **Default to "probably fabricated" for an unfamiliar service/feature
   name**, rather than assuming you missed it. Oracle's naming is
   fairly systematic (e.g., all Autonomous workload types follow an
   "Autonomous X Database/Processing/Warehouse" pattern); a name that
   grafts a competitor's brand onto an OCI term ("Azure HPC") or bolts
   an unrelated Oracle product name onto a naming convention
   ("Autonomous Blockchain Database") is a strong tell.
4. **Use the skill-check log and the Top 10 review list as a targeted
   drill deck** — the fabricated wrong answers are as valuable to study
   as the right ones, since they show exactly what Oracle's exam
   writers consider plausible-sounding bait.
5. **Mentally count before answering.** If a question says "which
   three," count how many listed options you're *certain* are real vs.
   how many you're inferring from vocabulary familiarity — that
   surfaces uncertainty before you commit, not after.

### Finite-lists cheat-sheet — closed sets to drill by count, not vocabulary

| Concept | Count | The exact list |
| --- | --- | --- |
| Database service categories | 4 | Oracle Database, Non-Oracle (MySQL), NoSQL Database, External Database |
| Autonomous DB workload types | 4 | ATP, ADW, AJD, APEX — **not** "Autonomous Blockchain Database" (fabricated distractor, seen on skill check) |
| Autonomous DB deployment options | 4 | Serverless, Dedicated, Exadata Cloud@Customer, Dedicated Region Cloud@Customer — **not** "Azure HPC" or "Dedicated Exadata infrastructure in AWS" (fabricated, seen on skill check) |
| Autonomous DB clone types | 3 | Full, Metadata, Refreshable |
| Clone sources | 2 | Live database instance (all 3 clone types available), Backup (full + metadata only — no refreshable clone from backup) |
| Autonomous Data Guard replication modes (Dedicated) | 2 | Maximum Availability, Maximum Performance |
| Globally Distributed ADB replication mechanisms | 2 | Oracle Data Guard (19c + 23ai), Raft Replication (23ai only) |
| Raft Replication factor choices | 3 | 3, 5, or 7 |
| Consumer group tiers — ATP/AJD | 5 | TPURGENT, High, Medium, Low (ADW gets only High/Medium/Low — 3, no TPURGENT) |
| Base Database Service backup destinations | 3 | Recovery Service, Object Storage, Local Storage (Local Storage does NOT survive DB System failure — the real trap) |
| Oracle Database 23ai named BaseDB features | 6 | AI Vector Search, Data Usercase Domains, Priority Transactions, True Cache, Rolling Patching, SQL Firewall |
| Autonomous Database Dedicated hard limits | 3 numbers | 12 ACDs per AVM Cluster; 200 ADBs per ACD (normally); 25 ADBs per ACD (with Data Guard enabled) |
| ARS protection policy tiers | 4 | Platinum (95 days), Gold (65 days), Silver (35 days), Bronze (14 days) |
| OCI Cache non-shard cluster node range | 1–5 nodes | 1 primary + up to 4 replicas |
| "What fully managed automates" (Autonomous vs. Base DB) | 4 | Backup, Patching, Upgrading, Tuning |

*Source detail for each row lives in [[6. Databases — OCI Database, NoSQL, Caching, DR]]. Add rows here as new finite lists turn up in other domains (Networking, Security, Compute, etc.) — this table is meant to grow beyond just Databases.*

## 5. Study approach adjustments vs. your AWS process
- Question banks (WhizLabs-equivalent for OCI) are useful for the MCQ portion only — don't mistake a high practice-test score for lab readiness.
- Build everything in Week 1-3 of the plan in an actual tenancy at least once without following a tutorial verbatim, close to exam conditions, before your final week.
- No personal weak-area baseline exists yet for this exam (unlike your AWS notes going back to 2019/2023) — this file will need real updates after your first practice assessment and again after the actual exam, the way your AWS tips file accumulated corrections over multiple passes.

---

## Open items to fill in as you go
- [ ] Exact current domain weightings (Oracle's public blueprint page, verify directly — not yet confirmed at time of writing)
- [ ] Whether your OCI employee status gives voucher/discount access to the $245 fee or paid Professional course content
- [ ] Post-practice-assessment: which domains are actually your weak spots (can't front-load this one, unlike AWS)
