# OCI Architect Professional Certification Plan — 1Z0-997-26

#certs #7_mystudy

**Starting point:** OCI Architect Associate ✓ · AWS SAA-C03 passed Friday, Aug 28, 2026 ✓  
**Exam:** OCI Architect Professional (1Z0-997-26). Register through [MyLearn’s current exam page](https://mylearn.oracle.com/ou/exam/oracle-cloud-infrastructure-architect-professional-1z0-997-26/163295/161770/271322).  
**Target exam date:** Not set. Use this as a four-week plan once you choose a date; schedule the official practice exam at the end of Week 3 before committing to the real exam.

**Exam logistics — confirmed directly from Oracle's own official prep workshop video** (MyLearn course 163275, "Prepare for OCI Architect Professional Certification," Samvit Mishra/Oracle University): **multiple-choice format**, 90 minutes, 50 questions, 68% passing score, no negative marking. Still reverify price ($245 as last checked) and registration/delivery rules on MyLearn's registration page before booking, since the workshop didn't restate those. Certification validity: 24 months from earn date. See [[OCI Architect Professional Tips]] Section 1 for the full test-taking-strategy notes and Section 6 for the confirmed domain weights.

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

## Exam domains — confirmed weights from Oracle's official prep workshop
Source: MyLearn course 163275, "Prepare for OCI Architect Professional Certification" — stated directly by the Oracle University instructor as the exam's own objective weighting (see [[OCI Architect Professional Tips]] Section 6 for full detail and per-domain named concepts).
1. Architect High Availability and Disaster Recovery Solutions — **15%**
2. Architect Cloud-Native Solutions — **20%**
3. Architect Security Solutions — **25%** (largest single domain)
4. Architecting, Implementing, and Operating Databases in OCI — **20%**
5. Implementing Observability Solutions — **20%**

Note: this 5-domain structure (with Security as its own 25% domain) supersedes the earlier 7-item placeholder list that had separate Multicloud/Migration domains — those topics don't appear as named top-level domains in the confirmed weighting.

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
  - [x] **Module: Data Protection** — Vault, encryption keys, secrets, Data Safe — covers your Vault/key build
  - [x] **Module: Maintaining Security Posture** — Cloud Guard, Security Zones, Monitoring, Logging & Events — covers the diagram/design half of Lab 4 plus your logging/audit retention piece
  - [x] There's also an **OS and Workload Protection** module (Bastion, vulnerability scanning, OS Management Hub) — not directly asked for in Lab 4, but it's the same territory as Note 8's AWS-translation table, so worth a skim if you have time

- [x] Compare Base Database Service, Autonomous Database, Exadata Cloud Service, RAC, Data Guard, and Autonomous Recovery Service by isolation, control, availability, operations burden, and licensing—not product trivia.
  - [x] RAC and BYOL licensing implications specifically — this is where OCI Pro diverges hardest from AWS; there's no direct AWS equivalent to Oracle licensing questions, so don't try to map it to a service comparison the way the rest of this plan does.
- [x] For every database scenario, force an answer to: “Why not the nearest AWS service?” This is where your SAA strength can otherwise overgeneralize.
- [x] Deliverable: a decision table for three sample workloads—cost-sensitive web app, regulated database, and low-RTO Oracle database.

### Week 3 — Hybrid/multicloud, migration, and observability

- [x] Work FastConnect (public/private virtual circuits), VPN, DRG, local versus remote peering, OCI-Azure Interconnect, Oracle Database@Azure, and Oracle Cloud VMware Solution into scenario flashcards.
  - [ ] Broaden this beyond just @Azure: know Oracle Database@AWS and @GCP positioning too (new as of 2026) — even without going deep on each, expect "which multicloud option fits this scenario" framed as a comparison across all three, not just Azure.
- [x] Build a migration runbook: discovery → landing zone → data move → cutover → validation → rollback. Contrast Application Migration, Database Migration, Zero Downtime Migration, and Data Transfer.
- [x] Configure one complete observability path: metric/log → alarm → Notifications → response owner. Add APM or Logging Analytics only where the use case calls for application tracing or richer log analysis.
- [x] Take the official practice exam/skill check from the learning path. Log every miss by domain, misconception, and missing service comparison; do not merely record the score.
- [x] Deliverable: ranked gap list and an error log with the corrected architectural rule for each miss.

## Top items to review before the exam

Running list, no longer capped at 10. Items 1–8 come from real, own-answer
misses across all five MyLearn skill checks taken so far (see [[MyLearn
Skill Check Questions]] for full question text and rationale) — not
guessed weak spots, only things actually gotten wrong first, whether
caught before submitting or not. Items 9–11 are lower-confidence
answer-key entries from the separate Quizlet-derived practice bank
([[practice-1-updated]], older 1Z0-997-22 exam version but same tested
concepts) flagged as "best-guess" there — included because they're
plausible real gaps, but weighted lower than 1–8 since they were never
actually attempted and self-graded. Items 12–17 come from the first 10
questions of the official MyLearn **Practice Exam 997-26** (50 questions
total, timed) — 6 misses out of 10 attempted so far, all logged live in
[[MyLearn Skill Check Questions]] with the full question, options, and
verification source. Items 13, 15, and 16 there are the model's own
doc-verified assessment rather than confirmed by the exam's own answer
key (no in-app grading screen was available at question-level) — flagged
inline; re-verify against the exam's summary/grading screen once you
finish it, and correct this list if any of those three turn out to
actually match your originally selected answer.
since they were never actually attempted and self-graded.

Items 18–30 come from **Practice Exam 997-26 attempt 2** (2026-09-25, self-scored ~64% all-or-nothing / ~69% with partial credit vs. 68% pass). Items 13 and 16 were reopened because they were missed in **both** attempts. Every trap is also in [[OCI Architect Professional Tips]] §4, and full question text is in [[MyLearn Skill Check Questions]] (attempt 2 section).

1. ✅ **COMPLETE** — **Network Firewall four-stage pipeline order** —
   Decryption Rules evaluate *first*, then Security Rules, then Tunnel
   Inspection, then NAT. Got this backwards on Skill Check: Architect
   Security Solutions Q4 (selected "security rules first, then
   decryption" — wrong order). Decryption goes first because every later
   stage needs to actually see the traffic's real content to inspect it
   meaningfully; NAT goes last because it only rewrites where allowed
   traffic goes, once the allow/deny decision is already made. Already
   documented in detail in [[5. Security — OCI IAM, WAF, Certificates,
   Vault, Cloud Guard]]'s "How the Network Firewall processes every
   packet — the four-stage pipeline" section.
2. ✅ **COMPLETE** — **Dedicated KMS's core value prop is
   single-tenant/full control, not shared.** Got this backwards on the
   same skill check Q5 (selected "DKMS offers a shared HSM partition
   managed by Oracle" — the opposite of DKMS's actual "Full
   Control"/single-tenant-partition benefit). Already documented in
   detail in [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud
   Guard]]'s "Dedicated Key Management" section, including all four
   named benefits (Full Control, High Security Standards/FIPS 140-2
   Level 3, PKCS#11 interfaces, Scalability/Availability) and the
   zero-default-service-limit provisioning trap.
3. ✅ **COMPLETE (concept)** — **Why a dynamic group is needed for
   Certificate Authority creation** — it's for the CA itself to make API
   calls to Vault/KMS as a resource principal (matches the real
   `OCI-SM-CA-DG` dynamic group seen live in Console), not "to create TLS
   certs after the CA is created." Got this wrong on the same skill check
   Q2 — confirmed correct by MyLearn's own grading, and now written up in
   [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]]'s
   "Why a dynamic group is needed for Certificate Authority creation"
   section. **Note the exam concept being marked complete here is
   separate from the actual working IAM policy statement**, which
   remains genuinely unresolved in `terraform/LABS.md`'s
   `lab-mymagnet-stack` entry (real CA creation against a real KMS key
   still fails with an authorization error after two different policy
   attempts) — don't treat this item as "the lab is fixed," only as "the
   exam-tested concept is confirmed correct."
4. ✅ **COMPLETE** — **Kubernetes Secret vs. ConfigMap for registry
   credentials.** Got this wrong on Skill Check: Design Cloud-Native...
   Q1 (selected ConfigMap — ConfigMap is for non-sensitive config only;
   registry credentials need a `kubernetes.io/dockerconfigjson`-type
   Secret, referenced via `imagePullSecrets`). A general Kubernetes
   concept, not OCI-specific — easy to blank on if K8s fundamentals are
   rusty. Full write-up, including the exact `kubectl create secret
   docker-registry` command shape, now in [[12. Containers — OCI OKE,
   Container Instances, OCIR]]'s "Managing OCIR images and security"
   section.
5. ✅ **COMPLETE** — **OCIR retention policy terminology: Global vs.
   Custom, not "Local."** Got this wrong on the same skill check Q3
   (selected a "local" retention policy option that isn't real OCIR
   terminology at all) — the real second policy type alongside Global is
   called **Custom**, scoped to specific repositories explicitly added to
   it. "Local" is a plausible-sounding synonym substituted for the real
   product term, not a fully fabricated feature — a subtler distractor
   variant. Already documented in [[12. Containers — OCI OKE, Container
   Instances, OCIR]]'s "Lifecycle/retention policies" section.
6. ✅ **COMPLETE** — **Terraform resource *type* is provider-specific;
   resource *name* is not.** Missed on Skill Check: Deliver
   Infrastructure-as-code Q5 (the FALSE-statement question) —
   `resource "<TYPE>" "<NAME>" {}` has two separate naming layers, and
   it's easy to conflate them under the generic phrase "resource names."
   Also covers the two other facts from that same question (provider
   aliases are real; CLI and provider versions are independently
   declared) and the Terraform-is-IaC-not-IaaS category distinction.
   Full write-up now in [[1. DevOps — OCI DevOps, CI-CD, Observability]]'s
   new "Terraform / Resource Manager — syntax precision, not just IaC
   concepts" section.
7. ✅ **COMPLETE** — **Monitoring is one of Oracle's three canonical HA
   design pillars (Redundancy/Failover/Monitoring) — not Scalability.**
   Missed, uncorrected, on Skill Check: Design Scalable and Elastic
   Solutions... Q5 — a real framing mismatch between Oracle's specific
   three-pillar answer and the more intuitive general "scalability +
   resilience" instinct. The one skill-check miss across all four that
   was never caught before submitting — worth extra attention for that
   reason alone. Full write-up now at the top of [[3. Compute — OCI
   Compute, Instance Pools, Load Balancers, Volumes]]'s "High
   availability and scaling" section.
8. ✅ **COMPLETE** — **Autonomous Database provisioning inputs:
   deployment type, network access type, workload type — NOT compute
   model/shape.** Missed, uncorrected even after a retry, on Skill Check:
   Autonomous Database Q1 — selected "compute model and shape" over
   "network access type" as one of the three core provisioning inputs.
   Compute model IS a real provisioning-time choice (locked afterward),
   and so is the superuser/admin password field — **every option in that
   question was a genuinely real Console field**, not a fabricated
   distractor; the trap was scope (which three *this* question wants),
   not authenticity. This skill check also repeatedly used
   **fabricated-but-plausible distractors elsewhere** (fake deployment
   options like "Azure HPC," a fake workload type "Autonomous Blockchain
   Database," a fake network access tier "OCI peered VCNs only") — see
   [[OCI Architect Professional Tips]] for the consolidated five-step
   strategy against that separate pattern. Full list of every real
   provisioning-screen field, and this exact "real fact vs. right scope"
   lesson, now documented in [[6. Databases — OCI Database, NoSQL,
   Caching, DR]]'s "Autonomous Database Serverless Provisioning" section.
9. ✅ **COMPLETE** — **BYOK import requires wrapping the key with the
   Vault's own RSA wrapping key.** Originally flagged low-confidence in
   `[[practice-1-updated]]` Q41 (best-guess answer A) — now confirmed
   correct and reconciled against Note 5's detailed, hands-on-confirmed
   mechanism: every vault ships a built-in RSA wrapping keypair by
   default (not user-created, cannot be created/deleted/rotated); on
   BYOK import, your external key material is encrypted with the vault's
   **public** wrapping key before it ever leaves your environment, using
   the fixed algorithm `RSA_OAEP_AES_SHA256`, and only unwrapped by the
   matching private half once inside OCI's HSM boundary — the raw key
   material is never transmitted or stored in plaintext at any point.
   See [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]]'s
   "Three key types Vault recognizes" section (Wrapping keys).
10. ✅ **COMPLETE — original guess was WRONG, now corrected.** OCI Audit
    log retention is **fixed at 365 days and cannot be changed** — a
    tenancy-level setting applying uniformly across all regions and
    compartments. The Quizlet-derived `[[practice-1-updated]]` Q21
    best-guess ("90–365 days, configurable") was **incorrect**; verified
    directly against Oracle's live "Audit Log Retention Period" doc page
    (`docs.oracle.com/en-us/iaas/Content/Audit/Tasks/settingretentionperiod.htm`),
    which states plainly: "Audit logs are retained for 365 days... The
    retention period cannot be changed." Confirmed further by checking
    the live Console directly — no retention-configuration control
    exists anywhere in the Audit Events page, consistent with it being a
    fixed, non-configurable value. **Also worth noting**: the Console
    banner during this check showed **"Audit will be deprecated in
    December 2025 within the OCI Console"** — CLI/SDK/API access for all
    Audit features continues with no interruption, but the Console UI
    surface itself is being phased out; worth watching for exam
    relevance since this is new information not previously in these
    notes. Already correctly documented (365 days, fixed,
    tenancy-level) in [[8. Management and Governance — OCI Resource
    Manager, OS Management Hub, Observability]]'s "Audit Logs —
    retention, structure, and IAM policy scope" section — that note was
    right all along; only the separate Quizlet-bank guess needed
    correcting.
11. ✅ **COMPLETE — original guess was PARTIALLY WRONG, now corrected.**
    Virtual Private Vault's two real, documented selection triggers (per
    Oracle's own text: "If you don't require the greater degree of
    isolation or the ability to back up the vault, you don't need a
    virtual private vault") are **greater isolation** and **the ability
    to back up the vault** (exclusive to Private Vault) — NOT "more key
    versions than a shared vault's limit," which was the
    `[[practice-1-updated]]` Q35 medium-confidence guess. That guess had
    the key-version direction **backwards**: a Default vault has
    essentially no hard key-version ceiling (pay-per-version), while
    Virtual Private Vault is the one with a capped allocation (1,000
    included by default, soft 1,000/hard 3,000 limit) — the opposite of
    "more headroom." Full correction now in [[5. Security — OCI IAM,
    WAF, Certificates, Vault, Cloud Guard]]'s "Virtual private vault"
    section.
12. ✅ **COMPLETE** — **Instance pool scale-in termination order: oldest
    instance first within a fault domain, NOT newest.** Missed on
    Practice Exam 997-26 Q2 — selected "newest" in an otherwise
    word-for-word correct option (AD-balance → FD-balance →
    terminate-first). Verified directly against Oracle's Autoscaling
    docs. A single-word distractor swap on a plausible-sounding option —
    the exact trap pattern this file already warns about, but landed on
    anyway because the rest of the sentence read as correct. Full
    write-up in [[3. Compute — OCI Compute, Instance Pools, Load
    Balancers, Volumes]]'s "High availability and scaling" section.
13. ⚠️ **REOPENED 2026-09-25 — missed again in Practice Exam attempt 2** (was marked complete) — **No "auto-decrypt" mechanism exists for
    Vault-encrypted Oracle Functions config variables — decryption is an
    explicit runtime API call in function code.** Missed on Practice
    Exam 997-26 Q3 (my doc-based assessment, not an in-app answer key —
    see [[MyLearn Skill Check Questions]] for the caveat). Selected an
    option describing automatic encrypt/decrypt via a config-variable
    reference; the real, documented pattern is encrypt offline → store
    ciphertext as a config variable → function code calls the Vault/KMS
    Decrypt API at runtime. Full write-up in [[14. Serverless — OCI
    Functions, Events, API Gateway]]'s "OCI Functions architecture"
    section.
14. ✅ **COMPLETE** — **OCI API Gateway has a native rate-limiting request
    policy — the fastest DDoS mitigation for a time-constrained scenario,
    no new service required, but not a complete DDoS solution by
    itself (doesn't stop a true distributed/volumetric flood — that
    needs WAF + rate limiting + platform L3/L4 protection layered
    together).** Missed on Practice Exam 997-26 Q4 — selected "VCN IP
    address segregation," which is not a real OCI feature (fabricated
    distractor). Reviewed and written up in full in
    [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]]'s
    "API Gateway's own native rate limiting — a real, fast DDoS lever,
    but a partial one" section (Edge and network protection). Also
    documented in [[14. Serverless — OCI Functions, Events, API
    Gateway]].
15. ✅ **COMPLETE** — **VNIC-blocked subnet deletion: use the CLI
    (`oci network vnic get --vnic-id <VNIC_OCID>`) to find the parent
    resource, not the Console search box.** Missed on Practice Exam
    997-26 Q6 (my doc-based assessment — see caveat in [[MyLearn Skill
    Check Questions]]). Verified against Oracle's VCN Troubleshooting
    guide: the documented method reads the VNIC's `display-name` via CLI
    to reveal its parent resource (load balancer, mount target, DB node);
    pasting the OCID into the Console search box isn't the documented
    approach. Full remediation sequence in [[9. Networking — OCI VCN,
    DRG, Gateways, Load Balancers]]'s "Troubleshooting: subnet/VCN
    deletion blocked by an attached VNIC" section; command itself also
    added to [[CLI Command Reference - OCI Architect Pro Study]]'s
    "Network Monitoring / Path Analyzer" section.
16. ⚠️ **REOPENED 2026-09-25 — missed again in Practice Exam attempt 2** (was marked complete) — **`oci kms crypto encrypt`/`decrypt` require the
    vault's Cryptographic Endpoint, not the Management Endpoint —
    passing the wrong one is a silent trap, not an obviously-labeled
    error.** Missed on Practice Exam 997-26 Q8 — misdiagnosed a
    `-management.kms.` endpoint as a missing region instead of the wrong
    endpoint type. This exact fact was already documented in Note 5
    before taking the question — a reminder to actually apply what's
    written, not just have it recorded. Full write-up and direct
    practice-exam cross-reference in [[5. Security — OCI IAM, WAF,
    Certificates, Vault, Cloud Guard]]'s "Every vault exposes two
    distinct, separately-addressed API endpoints" section.
17. ✅ **COMPLETE** — **"A microservice" (the individual unit) vs.
    "microservices architecture" (the overall pattern) are different
    definitions — read exam stems literally.** Missed on Practice Exam
    997-26 Q9 — picked the architecture-style definition when the
    question asked what a single microservice *is*. Oracle's own
    framing: a microservice is small, has one well-defined
    responsibility, and runs in its own process. Reviewed and understood
    — full write-up in [[14. Serverless — OCI Functions, Events, API
    Gateway]]'s "What a microservice actually is — a definitional trap,
    not an OCI-specific fact" section.

18. **Monitoring Query Language: Interval vs. the other parts.** Missed
    attempt 2 Q6 (picked Dimension for the aggregation window) and half of
    Q8 (thought Interval was optional). `metric[interval]{dimensions}
    .groupingFunction.statistic`: **required = metric, interval,
    statistic**; optional = dimensions and grouping function. Resolution
    ≠ Interval. See [[8. Management and Governance — OCI Resource Manager, OS Management Hub, Observability]].
19. **Logs from on-premises hosts: Agent Configuration + Service
    Connectors, not "Cloud Agent Plugin".** Missed attempt 2 Q29. Cloud
    Agent is for OCI instances; on-prem uses the standalone Unified
    Monitoring Agent configured by an Agent Configuration; Connector Hub
    archives to Object Storage. Built live in the capstone's
    `lab-capstone-observability-stack`.
20. **WAF rule types by threat.** Missed attempt 2 Q19. SQLi/XSS
    (content) → **protection rule**; request floods → **rate limiting**;
    who/where → **access control**.
21. **NSG rules and Network Firewall rules are independent; traffic must
    pass both.** Missed attempt 2 Q33. Key word is *rules*, not packet
    path order (same model as AWS SGs/NACLs/Network Firewall).
22. **Customer-managed key for an existing block volume = create Vault +
    MEK, assign the MEK.** Missed attempt 2 Q48. No manual
    decrypt/re-encrypt, never assign a DEK; Block Volume handles data
    keys (envelope encryption).
23. **OCIR push/pull prerequisite is an auth token.** Missed attempt 2
    Q7 (picked Kubernetes docker-registry secret, which is for OKE pulls
    and is built *from* the token).
24. **Autonomous Recovery Service near-zero data loss = continuous redo
    shipping.** Missed at first on attempt 2 Q4 (block volume replication
    trap). See [[6. Databases — OCI Database, NoSQL, Caching, DR]].
25. **Logical corruption, keep evidence → clone from a pre-corruption
    backup, don't restore production in place.** Missed attempt 2 Q5.
26. **Base Database version upgrades are NOT rolling, even on 2-node RAC,
    and pre-upgrade backups can't restore across the version boundary.**
    Missed attempt 2 Q40; the note already had it word for word (recall,
    not knowledge, gap).
27. **Load balancer routing order: listener by virtual hostname → path
    route set → listener's default backend set.** Missed attempt 2 Q11.
    Worked example in [[9. Networking — OCI VCN, DRG, Gateways, Load Balancers]].
28. **VCN-to-VCN in one region: LPG↔LPG, or one DRG with both VCNs
    attached; an LPG never peers with a DRG.** Half-missed attempt 2 Q45.
29. **Block volume multi-attach rules.** Missed attempt 2 Q21: once
    attached read-only, further attachments must be read-only;
    read/write non-shareable is exclusive; attachments are same-AD only.
30. **Reversed questions ("which is NOT valid", "expensive or
    impractical").** Missed attempt 2 Q15 (half) and Q30 (picked the
    valid wallet method; the fabricated `CreateConnection` API was the
    answer). Method: eliminate every option you recognize as real; the
    leftover is the answer. Also watch "not"-flipped real checks (attempt
    2 Q20: restart dcsagent, ARCHIVELOG, DB running).

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
