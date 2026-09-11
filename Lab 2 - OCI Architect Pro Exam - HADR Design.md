# Lab 2 - OCI Architect Pro Exam - HA/DR Design

#7_mystudy #OCI  
**Plan item:** Design — not necessarily provision — an HA/DR pattern. Include AD/fault-domain placement, backup versus replication, RPO/RTO, and failover ownership. Grounded in [Full Stack Disaster Recovery](https://docs.oracle.com/en-us/iaas/disaster-recovery/doc/about-disaster-recovery.html) docs alongside Data Guard concepts.

**This is a design exercise, not a build** — no Terraform, no Resource Manager stack. The deliverable is a documented architecture decision, which is exactly the artifact type the HPE lab and scenario questions actually test in the HA/DR domain (Note 8.1's Week 1 hands-on labs cover the *build* side; this covers the *design reasoning* side).

The diagram lays out the two-region pattern from the design: the primary region's app tier spread across Availability Domains with the Data Guard primary database, mirrored by a cold standby app tier and warm Data Guard standby database in the second region. The dashed lines show what's not active by default — Traffic Management's failover routing and Full Stack DR's orchestrated failover path — versus the solid line showing normal traffic and the continuous Data Guard replication link between the two databases.
One thing the diagram can't show but is worth restating from the design doc: that dashed failover arrow at the bottom is **manually triggered**, not automatic — a deliberate choice given how consequential a full region failover is.

![](Lab%202%20-%20OCI%20Architect%20Pro%20Exam%20-%20HADR%20Design/oci_ha_dr_design.png)
---

## Scenario used for this design

Reusing the three-tier shape from Note 9 (baseline pattern) so the design vocabulary stays consistent across notes: public Load Balancer → application tier (Compute or OKE) → database tier (Base Database Service with Data Guard). Assume a regulated workload with a genuinely tight RTO requirement — this forces real design tradeoffs rather than defaulting to "just use backups."

---

## 1. AD / Fault Domain placement

**Key fact worth confirming before designing anything:** not every OCI region has 3 Availability Domains. Only the original regions — **Ashburn, Phoenix, London, and Frankfurt** — have 3 ADs. The large majority of newer regions have **only 1 AD**. This changes the whole design conversation: in a 1-AD region, intra-region resilience is achieved entirely through **Fault Domains** (3 per AD, always — even in 1-AD regions), not AD spread. Always check which case you're in before assuming a 3-AD design pattern applies.

**Within a single AD (or a 1-AD region): Fault Domains**
- Spread app-tier compute instances or OKE node pools across all 3 Fault Domains — protects against hardware/rack-level failure, not a full AD outage.
- Fault Domains are anti-affinity groupings only — they don't cross AD boundaries, so they provide zero protection against an AD-wide event in a 3-AD region, or a region-wide event anywhere.

**Across ADs (3-AD regions only): Availability Domain spread**
- App tier: distribute Compute instances or OKE node pools across all 3 ADs behind the Load Balancer, so an AD outage removes at most 1/3 of app capacity, not all of it.
- Database tier: Data Guard standby placed in a **different AD** within the same region protects against AD-level failure without needing a second region at all — this is the layer most people skip, jumping straight to "we need DR in another region" when an intra-region, cross-AD standby might already satisfy the RPO/RTO for AD-level (not region-level) outages.
- Load Balancer: OCI's Load Balancer service is itself already deployed redundantly across ADs by Oracle within a region that has multiple ADs — this isn't something you configure, it's inherent to the managed service.

**This design's placement decision:** app tier spread across 3 ADs (assumes a 3-AD region); Data Guard standby in a second AD in the *same* region for AD-level HA; a second, geographically separate region for actual DR (region-level disaster), using Full Stack DR to orchestrate the whole-stack failover.

---

## 2. Backup versus replication — by tier, not as a blanket choice

This is the trap: treating "backup vs. replication" as one tenancy-wide decision rather than a per-tier, per-RPO decision.

| Tier | Backup | Replication | This design's choice |
|---|---|---|---|
| Database | Automatic/manual backups (Object Storage-backed) — cheap, but RPO = time since last backup, RTO = restore time | Data Guard (physical standby, continuous redo apply) — RPO near-zero to seconds, RTO = switchover/failover time | **Replication (Data Guard)** — the RPO requirement here can't tolerate backup-only |
| Block storage (app tier boot/data volumes) | Volume backups (scheduled, Object Storage-backed) | Cross-region Block Volume replication (available for supported volume types) | **Backup**, since app tier is stateless-by-design here (state lives in the DB) — replication would be paying for redundancy the architecture doesn't need |
| Object Storage (static assets, artifacts) | N/A — durable by design within a region | Cross-region replication (bucket-level) | **Replication** if the standby region needs to serve traffic without a live dependency back on the primary region during an outage |
| Compute/app tier itself | Custom images (periodic) | N/A — stateless tier is rebuilt from Terraform/image, not replicated | **Neither in the traditional sense** — this tier's "DR" is Full Stack DR's Launch Compute Instance built-in plan step, rebuilding from a known-good image/config, not restoring backed-up state |

**The general principle to state explicitly in any design:** backup buys you a cheaper RPO/RTO than replication, but never a *better* one. If a requirement's RPO is tighter than your backup interval, backup alone cannot satisfy it — full stop, regardless of how good the backup policy is. This is a common exam-scenario tell: a stated RPO in seconds or single-digit minutes almost always eliminates backup-only DB designs and forces Data Guard (or GoldenGate for more exotic replication needs).

---

## 3. RPO / RTO — defining them precisely, and mapping design choices to them

Per Oracle's own Full Stack DR terminology (verified against current docs):
- **RPO (Recovery Point Objective)** — maximum *data loss* tolerable, expressed in time. Answers: "how much data can we afford to lose?"
- **RTO (Recovery Time Objective)** — maximum *downtime* tolerable, expressed in time. Answers: "how long can we be down?"

These are independent numbers and commonly conflated — a design can have a tight RTO and a loose RPO (fast to bring back up, but okay losing an hour of data) or the reverse (can tolerate being down a while, but can't lose any committed data). State both explicitly and separately for any design; never let one imply the other.

**This design's stated targets (example, adjust per actual requirement):**
- RPO: near-zero (seconds) — justifies Data Guard over backup-only for the DB tier
- RTO: under 15 minutes for AD-level failure (intra-region Data Guard switchover); under 1 hour for full region-level failure (Full Stack DR-orchestrated failover to standby region)

**Warm Standby vs. Cold Standby (Full Stack DR terminology) — the RTO/cost tradeoff made explicit:**
- **Warm Standby**: some/all components pre-deployed in the standby region ahead of time. Higher ongoing cost, lower RTO — the standby app tier and DB replica are already running or nearly so.
- **Cold Standby**: little/nothing pre-deployed; components are stood up as part of the DR transition itself. Lower ongoing cost, higher RTO — you're paying in time what you saved in standing infrastructure.
- **This design's choice**: Warm Standby for the database (Data Guard standby is inherently "warm" — continuously applying redo) combined with a largely Cold app tier (rebuilt from image/Terraform during failover) — a common, deliberately mixed pattern rather than uniformly warm or cold across the whole stack.

---

## 4. Failover ownership — who/what actually triggers and executes it

This is the part most designs leave vague, and exactly what the plan item is calling out by name. Three distinct layers of "failover," each with a different owner:

### Layer 1 — Database-level: Data Guard's own switchover/failover
- **Switchover**: planned, no data loss, both primary and standby are healthy and reachable — this is a role swap, not a disaster response.
- **Failover**: unplanned, standby becomes primary because the original primary is unreachable — potential data loss depending on protection mode (Maximum Availability/Performance/Protection — covered in Note 5's AWS-translation table).
- **Owner**: DBA/database team, or automated via Data Guard's Fast-Start Failover for a fully automatic unplanned transition without waiting on human judgment.

### Layer 2 — Whole-stack level: Full Stack DR's own switchover/failover
**Naming collision worth flagging explicitly — this is a real exam trap:** Full Stack DR uses the *exact same terms* — "Switchover" and "Failover" — but at a completely different scope: the entire application stack (compute, network config, DB role, everything in a DR Protection Group), not just the database role. Per Oracle's own terminology docs:
- **Switchover** (Full Stack DR): planned transition, orderly shutdown of the primary stack, then bring-up in standby — requires both regions' stack components to be available.
- **Failover** (Full Stack DR): unplanned transition, brings up the standby stack immediately without attempting to shut down the primary — only requires the standby region to be available, which is exactly why it's the disaster-response path.
- **Owner**: whoever operates the DR Protection Group pairing — typically a platform/SRE team, executing a pre-built and pre-validated **DR Plan** rather than making ad hoc decisions mid-incident. The DR Plan itself is composed of **Plan Groups** (parallel steps) run in sequence, many of them **Built-In Steps** (e.g., "Launch Compute Instance," "Switchover Database") that Full Stack DR generates automatically from the DR Protection Group's actual members.

### Layer 3 — DNS/traffic level
- Once the standby region's stack is live (via either layer above), something has to actually redirect traffic — OCI Traffic Management steering policies (Failover steering, per Note 9) handle this, bounded by DNS TTL.
- **Owner**: whoever owns the DNS/Traffic Management configuration — this step is easy to forget as a separate ownership question distinct from "did the standby come up successfully."

**This design's explicit failover ownership statement (the artifact the plan item is actually asking for):**
- AD-level DB failure → Data Guard Fast-Start Failover, **automatic**, no human decision in the loop, sub-minute detection.
- Region-level disaster → Full Stack DR **Failover** plan execution, **manually triggered** by the on-call platform lead after confirming the primary region is genuinely unreachable (not automatic — a region-level failover is consequential enough that Oracle's own model treats it as a deliberate, human-triggered plan execution, not an automatic response).
- Traffic redirection → Traffic Management Failover steering policy, **automatic** once health checks detect the primary origin is down, bounded by the configured TTL.

---

## 5. Validating the design without actually disrupting production: DR Drill and Precheck

Two Full Stack DR concepts worth designing in from the start, not bolted on later:
- **Precheck**: validates that a DR Plan is still compliant with the current state of its DR Protection Groups — catches drift (a new compute instance added to the primary that never got mirrored into the DR Plan, for example). Run this on a schedule, not just before an actual disaster.
- **DR Drill**: brings up a real replica of the application stack in the standby region for testing, without calling it a "real" failover — validates that the DR Plan actually works, on a cadence, rather than discovering it doesn't during a real incident. A **Start DR Drill** execution creates the replica; **Stop DR Drill** tears it down afterward.

**This design's cadence (state this explicitly in any real design):** Precheck monthly; full DR Drill quarterly. A DR plan that has never been drilled is a documented assumption, not a tested capability — worth saying exactly that plainly in a design review.

---

## Recall / design exercises

- [ ] A requirement states RPO of 5 minutes and RTO of 4 hours for a database tier. Is backup-only viable? Justify using the RPO/RTO definitions above, not intuition.
- [ ] Explain the difference between "Switchover" at the Data Guard layer and "Switchover" at the Full Stack DR layer. If asked to design a DR plan for a database-only outage vs. a full region outage, which layer's switchover applies to each?
- [ ] A region has only 1 Availability Domain. What does "AD-level HA" mean in that region, if anything, and what's the actual resilience mechanism available?
- [ ] Design the failover ownership statement (who/what triggers each layer) for a workload with a stricter requirement: RTO under 5 minutes for a full region failure. Does "manually triggered by an on-call lead" still satisfy that RTO? What would need to change?
- [ ] Explain why a DR Plan that has never had a DR Drill run against it is a liability even if it looks correct on paper. What specific kind of failure does a Drill catch that a Precheck alone would not?
- [ ] A design uses Warm Standby for the database and Cold Standby for the app tier. Justify this as a deliberate choice rather than an inconsistency — what does each tier's actual statefulness have to do with the decision?

## Official references

- [About Full Stack Disaster Recovery](https://docs.oracle.com/en-us/iaas/disaster-recovery/doc/about-disaster-recovery.html)
- [Full Stack DR Terminology and Concepts](https://docs.oracle.com/en-us/iaas/disaster-recovery/doc/disaster-recovery-terminology.html) — source for the RPO/RTO, Switchover/Failover, Warm/Cold Standby, DR Drill, and Precheck definitions used above
- [Regions and Availability Domains](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm) — source for the 3-AD-regions-are-the-exception fact
- Data Guard protection modes — see [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]] AWS-translation table and Note 8 for related governance patterns
