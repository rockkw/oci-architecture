# OCI Architect Professional Certification Plan — 1Z0-997-26

#certs #7_mystudy

**Prerequisite held:** OCI 2025 Certified Architect Associate ✓
**Exam:** OCI Architect Professional (1Z0-997-26) — Oracle dropped the calendar year from the credential *title* as of an Aug 10, 2026 announcement, but the exam code itself is still versioned (1Z0-997-26). 90 min, 50 questions, 68% passing, $245.
**Target exam date:** *(not set — plug in once your AWS recert window (SAP-C02, Sep 9) clears. This plan assumes a ~4-week runway; shift weeks proportionally once you pick a date.)*

## The one thing that's different from your AWS approach
This is a **Hands-on Performance Exam (HPE)** — live lab tasks in an actual OCI console/CLI environment, graded with partial credit per sub-task, combined with multiple-choice questions. Question banks and brain-dump-style practice tests (your WhizLabs/Tutorials Dojo approach for AWS) will **not** get you through the lab portion. You need real reps building things in an OCI tenancy — the free tier is enough for most of this. Budget more hands-on time and less pure question-drilling time than your AWS plan.

Also unlike your AWS recert: you have **no personal weak-area history** for this exam (first attempt, not a recert), so this plan covers all seven domains rather than front-loading known gaps. Once you do a practice assessment, you can trim time from domains you're already strong in (likely networking and IAM, given your AWS/OCI background) and add it to the domains below.

## Exam domains (per Oracle's published blueprint)
1. Cloud-native architecture design (OKE, Functions, API Gateway, Resource Manager/Terraform)
2. High availability and disaster recovery
3. Security architecture
4. Database architecture (including Oracle-specific: Data Guard, Autonomous Database, Exadata)
5. Multicloud and hybrid architecture
6. Workload migration
7. Observability and management

---

## Week 1 — Lab Environment + Cloud-Native & HA/DR
- [ ] Stand up an OCI Free Tier tenancy (or use your Oracle work tenancy if permitted) as your lab environment for the whole plan
- [ ] OKE (Kubernetes) — deploy a basic cluster, understand node pools vs. virtual nodes
- [ ] OCI Functions (serverless) — deploy and invoke a function
- [ ] API Gateway — front a function or backend with a deployment
- [ ] Terraform + Resource Manager — provision one stack via Resource Manager, not just click-ops
- [ ] HA/DR: Data Guard (Standard vs. Fast-Start Failover), region-to-region DR patterns, backup/restore vs. pilot light equivalents in OCI terms
- [ ] Oracle University: paid Professional-level course access (confirm what's included vs. what needs separate purchase now that Professional courses are no longer free)

## Week 2 — Security + Database Architecture
- [ ] IAM policies (compartments, dynamic groups, policy syntax) — build 2-3 real policies, don't just read them
- [ ] Identity domains (OCI's newer IAM layer vs. legacy IAM) — know when each applies
- [ ] Vault/KMS equivalent, encryption at rest/in transit patterns
- [ ] Security zones and cloud guard — set up one security zone in your lab tenancy
- [ ] Database architecture: Autonomous Database (Shared vs. Dedicated), Exadata Cloud Service positioning, Data Guard deep-dive (this overlaps HA/DR — expect it tested from both angles)
- [ ] RAC and BYOL licensing implications in architecture decisions (this is where OCI Pro diverges hardest from AWS — no direct AWS equivalent to Oracle licensing questions)

## Week 3 — Multicloud/Hybrid, Migration, Observability
- [ ] Multicloud: Oracle Database@AWS / @Azure / @GCP positioning (new as of 2026 — know what each is even if you don't go deep, likely to appear as "which multicloud option fits this scenario")
- [ ] FastConnect (OCI's Direct Connect equivalent) — public vs. private peering, partner vs. dedicated
- [ ] Migration: Application Migration service, Database Migration service, Zero-Downtime Migration for Oracle DBs specifically
- [ ] Observability: Logging, Monitoring, Application Performance Monitoring (APM), Events service — build one alarm + notification end to end in your lab tenancy
- [ ] First full practice assessment (Oracle's official practice exam if available under your paid course access) — baseline score, log missed domains

## Week 4 — Gap Fill + Exam
- [ ] Re-drill weakest 2-3 domains from Week 3's practice assessment
- [ ] Repeat key hands-on labs cold (no notes) to confirm you can execute under exam time pressure, not just recognize the right answer
- [ ] Review Oracle's official exam prep guide PDF for 1Z0-997-26 if published (check the exam info page directly — Oracle doesn't announce blueprint changes, you have to check yourself)
- [ ] Pre-exam ritual (same as AWS: Chrome browser, water, espresso, bagel, Advil 30 min prior)
- [ ] **Sit 1Z0-997-26**

---

## Notes
- Verify the exam page yourself before finalizing dates: `education.oracle.com` — search "Oracle Cloud Infrastructure Architect Professional" for the current pexam code and any objective changes. Oracle doesn't send update notifications, same as their long-standing policy on AWS-equivalent recert pages.
- Certification validity: 24 months from earn date (unchanged).
- Given your OCI Director role, check whether Oracle internal employee training/voucher benefits apply before paying the $245 out of pocket.
