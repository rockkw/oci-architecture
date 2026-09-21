# OCI Architect Professional Certification Plan — 1Z0-997-26

#certs #7_mystudy

**Starting point:** OCI Architect Associate ✓ · AWS SAA-C03 passed Friday, Aug 28, 2026 ✓  
**Exam:** OCI Architect Professional (1Z0-997-26). Register through [MyLearn’s current exam page](https://mylearn.oracle.com/ou/exam/oracle-cloud-infrastructure-architect-professional-1z0-997-26/163295/161770/271322).  
**Target exam date:** Not set. Use this as a four-week plan once you choose a date; schedule the official practice exam at the end of Week 3 before committing to the real exam.

**Exam logistics (as last checked; reverify on MyLearn before booking per the correction below):** 90 minutes, 50 questions, 68% passing score, $245. Certification validity: 24 months from earn date.

**Given your OCI Director/internal-employee role:** check whether Oracle internal employee training or exam-voucher benefits apply before paying the $245 out of pocket.

**Active work session:** [Claude Code session](https://claude.ai/code/session_01Vk4Mik3VXSrWCwEuNZxm4s) —
the `lab-oke-stack` node registration timeout is resolved (see
`terraform/LABS.md`) and [[12. Containers — OCI OKE, Container Instances, OCIR]]
is fully rewritten to OCI-native content. Terraform work has since moved on to
`lab-document-understanding-stack` (event-driven OCR pipeline) and
`lab-mymagnet-stack` (AWS→OCI lift-and-shift), both in `terraform/LABS.md`.
**Next open item in this plan is Week 2**: the four remaining security modules
(Network Security, Data Protection, Maintaining Security Posture, OS and
Workload Protection) and the database-service comparison deliverable. Resume
with `claude --continue` in the OCI_Pro_Notes directory.

## Important 2026 correction

Treat this as an **online, scenario-based certification exam**, not a Hands-on Performance Exam. Oracle’s 2025 Architect Professional learning path described an online certification exam of **1 hour 30 minutes**; the 2026 version replaced that exam in June. Confirm the live duration, number of questions, passing score, price, delivery rules, and objectives on the MyLearn registration page immediately before booking—those operational details can change.

Hands-on work is still essential, but it is preparation for architectural judgment: explain the trade-off, then build a small proof of the design. Do not use exam dumps or leaked question banks.

## Exam domains (per Oracle's published blueprint — reverify against the current MyLearn objectives page, per the correction above)
1. Cloud-native architecture design (OKE, Functions, API Gateway, Resource Manager/Terraform)
2. High availability and disaster recovery
3. Security architecture
4. Database architecture (including Oracle-specific: Data Guard, Autonomous Database, Exadata)
5. Multicloud and hybrid architecture
6. Workload migration
7. Observability and management

Tenant sign in - 
1. **rocwyvpy14**
2. https://cloud.oracle.com/?region=us-ashburn-1
3. idtlmgo3jgde/oracleidentitycloudservice/rock.whitney@oracle.com
4. Auth token - [REDACTED — see local password manager]

## Official study spine

1. Enroll in the [current OCI Architect Professional learning path](https://mylearn.oracle.com/ou/learning-path/become-an-oci-architect-professional/163270). Oracle University support confirmed that the course’s **Student Guide** and **Activity Guide** are the source of the hands-on exercise material.
2. Complete the course labs and skill checks before adding third-party practice questions. The preceding official path included 32+ hours of instruction/labs, a preparation module, and a practice exam; use the current path’s equivalent modules as the source of truth.
3. Use the [OCI Architecture Center / Well-Architected Framework](https://www.oracle.com/cloud/architecture-center/) to rehearse trade-offs across security, reliability, performance, cost, and operations.
4. Keep the [OCI cheat sheet](OCI-Architect-Pro-Cheat-Sheet-2026.PNG) open only as a rapid service-recall aid. Its service groupings are useful; verify every exam-format or weighting statement against MyLearn.

## Four-week plan

### Week 1 — Translate AWS instincts; cloud-native and HA/DR

- [x] Spend one focused session translating your fresh SAA-C03 knowledge: VPC → VCN, IAM roles → dynamic groups/policies, Direct Connect → FastConnect, S3/EBS/EFS → Object/Block/File Storage, CloudWatch → Monitoring/Logging/APM. Record the places where the analogy breaks.
- [x] Complete the learning-path modules/labs for OKE, Functions, API Gateway, OCI DevOps/OCIR, Terraform, and Resource Manager.
  - [x] MyLearn course sections 1–4 (Introduction, HA/DR, Cloud-Native Solutions, Infrastructure as Code) — skill checks passed: Design Cloud-Native/Serverless (100%), Deliver Infrastructure-as-code (100%), HA/DR (80%). See [[MyLearn Skill Check Questions]] for the full question log, and [[12. Containers — OCI OKE, Container Instances, OCIR]] / [[14. Serverless — OCI Functions, Events, API Gateway]] / [[1. DevOps — OCI DevOps, CI-CD, Observability]] for the course-notes capture.
- [x] In a non-production tenancy, deploy one small reference workload: API Gateway → Function or OKE service; provision at least one component through [Resource Manager](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/resourcemanager.htm), not click-ops.[
  - [x] [CLI Command Reference — OCI Architect Pro Study]]
  - [x] [[Lab 1 - OCI Architect Pro Exam]]
- [x] Design—not necessarily provision—an HA/DR pattern. Include AD/fault-domain placement, backup versus replication, RPO/RTO, and failover ownership. Study [Full Stack Disaster Recovery](https://docs.oracle.com/en-us/iaas/disaster-recovery/doc/about-disaster-recovery.html) alongside Data Guard concepts.
  - [x] [[Lab 2 - OCI Architect Pro Exam - HA\/DR Design]]
- [x] Deliverable: a one-page “AWS to OCI exceptions” note plus an architecture sketch with named failure modes. See [[AWS to OCI Exceptions]].

### Week 2 — Security, governance, and database choices
**~[Become a Cloud Security Professional \(2025\)](https://learn.oracle.com/ols/learning-path/become-a-cloud-security-professional-2025/118071/147744)~**

- [x] **Build and test 2–3 compartment-scoped IAM policies, including a dynamic group. Explain least privilege, policy scope, and identity-domain versus IAM use.**
  - [x] [[Lab 3 - OCI Architect Pro Exam - IAM Policies]]
- [x] **complete Module: OCI Identity and Access Management** — covers exactly Lab 3's scope: Identity Domains, Users, Groups, Policies, Compartments, Dynamic Groups, and Advanced Policies
  - [x] Optional deeper dive if you want more than the learning path's module: standalone course **~[Managing OCI Identity and Access Management](https://learn.oracle.com/ols/course/managing-oci-identity-and-access-management/118071/135706)~** — same topic, more hands-on depth if the learning path's module feels thin after everything you already did live in Lab 1/3
  
- [x] Configure or diagram Vault, Cloud Guard, Security Zones, logging/audit retention, and a network boundary (NSGs/security lists, WAF or Network Firewall) appropriate to a web workload.
  - [x] [[Lab 4 - OCI Architect Pro Exam - Vault, Guard, Zones, Logging, Network Boundary]]
- [ ] complete **Module: Network Security** — Security Lists, NSGs, Network Firewall, WAF, Certificates, Load Balancers — covers your NSG build and the WAF-vs-Network-Firewall design decision directly
  - [x] Zero Trust Packet Routing (ZPR) — see [[Lab 5 - OCI Architect Pro Exam - Zero Trust Packet Routing]] for the hands-on Terraform build (VM-01/VM-02 SSH lockdown, `lab-zpr-stack`, dry-run verified)
  - [ ] **Module: Data Protection** — Vault, encryption keys, secrets, Data Safe — covers your Vault/key build
  - [ ] **Module: Maintaining Security Posture** — Cloud Guard, Security Zones, Monitoring, Logging & Events — covers the diagram/design half of Lab 4 plus your logging/audit retention piece
  - [ ] There's also an **OS and Workload Protection** module (Bastion, vulnerability scanning, OS Management Hub) — not directly asked for in Lab 4, but it's the same territory as Note 8's AWS-translation table, so worth a skim if you have time

- [ ] Compare Base Database Service, Autonomous Database, Exadata Cloud Service, RAC, Data Guard, and Autonomous Recovery Service by isolation, control, availability, operations burden, and licensing—not product trivia.
  - [ ] RAC and BYOL licensing implications specifically — this is where OCI Pro diverges hardest from AWS; there's no direct AWS equivalent to Oracle licensing questions, so don't try to map it to a service comparison the way the rest of this plan does.
- [ ] For every database scenario, force an answer to: “Why not the nearest AWS service?” This is where your SAA strength can otherwise overgeneralize.
- [ ] Deliverable: a decision table for three sample workloads—cost-sensitive web app, regulated database, and low-RTO Oracle database.

### Week 3 — Hybrid/multicloud, migration, and observability

- [ ] Work FastConnect (public/private virtual circuits), VPN, DRG, local versus remote peering, OCI-Azure Interconnect, Oracle Database@Azure, and Oracle Cloud VMware Solution into scenario flashcards.
  - [ ] Broaden this beyond just @Azure: know Oracle Database@AWS and @GCP positioning too (new as of 2026) — even without going deep on each, expect "which multicloud option fits this scenario" framed as a comparison across all three, not just Azure.
- [ ] Build a migration runbook: discovery → landing zone → data move → cutover → validation → rollback. Contrast Application Migration, Database Migration, Zero Downtime Migration, and Data Transfer.
- [ ] Configure one complete observability path: metric/log → alarm → Notifications → response owner. Add APM or Logging Analytics only where the use case calls for application tracing or richer log analysis.
- [ ] Take the official practice exam/skill check from the learning path. Log every miss by domain, misconception, and missing service comparison; do not merely record the score.
- [ ] Deliverable: ranked gap list and an error log with the corrected architectural rule for each miss.

## Top 10 items to review before the exam

Running list, populated from real skill-check misses (see
[[MyLearn Skill Check Questions]] for full question text and rationale) —
not guessed weak spots, only things actually gotten wrong first.

1. **Network Firewall four-stage pipeline order** — Decryption Rules
   evaluate *first*, then Security Rules, then Tunnel Inspection, then NAT.
   Got this backwards on Skill Check: Architect Security Solutions Q4
   (selected "security rules first, then decryption" — wrong order).
2. **Dedicated KMS's core value prop is single-tenant/full control, not
   shared.** Got this backwards on the same skill check Q5 (selected "DKMS
   offers a shared HSM partition managed by Oracle" — the opposite of
   DKMS's actual "Full Control"/single-tenant-partition benefit).
3. **Why a dynamic group is needed for Certificate Authority creation** —
   it's for the CA itself to make API calls to Vault/KMS as a resource
   principal (matches the real `OCI-SM-CA-DG` dynamic group seen live in
   Console), not "to create TLS certs after the CA is created." Got this
   wrong on the same skill check Q2 — and this is the exact same
   unresolved authorization gap `terraform/LABS.md`'s `lab-mymagnet-stack`
   entry has been stuck on (real IAM policy grants for the CA's key access
   still failing) — a live, hands-on confirmation of a concept this test
   also caught as a knowledge gap.

### Week 4 — Retrieval practice and booking gate

- [ ] Re-study only the lowest two or three domains from the error log, using the relevant MyLearn module, Student/Activity Guide, and official docs.
- [ ] Redraw two architectures cold: (1) secure highly available web/database stack, (2) hybrid migration with DR. Defend each service choice out loud in 90 seconds.
- [ ] Repeat the official practice assessment or targeted skill checks. Book the exam only after you can explain every wrong answer and meet a personal readiness threshold you set in advance.
- [ ] Verify the MyLearn exam page the day before booking and again before the exam—version, delivery conditions, and policies are authoritative there.

## Oracle-internal resources found

- [MyLearn exam page](https://mylearn.oracle.com/ou/exam/oracle-cloud-infrastructure-architect-professional-1z0-997-26/163295/161770/271322) — Oracle Learning confirmed in Slack that education.oracle.com exam pages are being migrated to MyLearn.
- [MyLearn learning path](https://mylearn.oracle.com/ou/learning-path/become-an-oci-architect-professional/163270) — use the in-course Student Guide and Activity Guide for labs; for content questions use the course player’s **Ask the Instructor** option.
- [Oracle University Digital Learning Support](https://oracle.enterprise.slack.com/archives/C023N32M60H) — the internal escalation channel if the current path, lab access, or exam enrollment is unclear.

## Practice-test guidance

- **Start with MyLearn.** Complete the learning path’s practice assessment and skill checks before using third-party questions; use missed answers to drive your domain error log.
- **Whizlabs:** no current Whizlabs practice-test listing was found for **1Z0-997-26**. Do not purchase an older OCI Architect Professional version unless it explicitly names the 2026 exam code and covers the current objectives.
- **Optional third-party simulation:** [OCIExams’ 1Z0-997-26 practice tests](https://www.ociexams.com/courses/oci-architect-professional) advertises three 50-question, 90-minute tests. Treat it only as scenario practice: validate explanations against MyLearn and Oracle documentation, and do not use dumps or “real-question” banks.

## Exam-week checklist

- [x] MyLearn registration and delivery details rechecked
- [ ] Official course completed; Student/Activity Guide notes indexed by domain
- [ ] Two cold architecture explanations completed
- [ ] Official practice gaps closed—not just score improved
- [ ] Lab tenancy cleaned up or confirmed within permitted cost controls
