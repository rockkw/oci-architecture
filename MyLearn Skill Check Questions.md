# MyLearn Skill Check Questions — OCI Architect Professional (2026)

#7_mystudy #OCI

*Captured live from MyLearn course skill checks, as taken. Distinct from
[[practice-1-updated]], which is sourced from a Quizlet flashcard set —
keep these separate since they come from different sources.*

**Recurring exam pattern**: several skill-check questions mix real OCI
concepts with fabricated-but-plausible-sounding options. See [[OCI
Architect Professional Tips]] for the full write-up (two distractor
flavors, the five-step prep strategy, and the finite-lists cheat-sheet)
— flagging each instance below as it comes up.

---

## Skill Check: Design Cloud-Native, Microservices, and Serverless Architecture

### Q1
What Kubernetes object can be used to store the Oracle Cloud Infrastructure credentials needed to pull an image from a private registry in OCI?

A. Ingress
B. ConfigMap
C. Secret
D. Service

**Answer: C** (initially selected ConfigMap — incorrect; corrected to Secret before submitting)

*Secret (specifically type `kubernetes.io/dockerconfigjson`) is what stores registry credentials, referenced via `imagePullSecrets` in a pod spec — this is a general Kubernetes concept, not OCI-specific. ConfigMap is for non-sensitive configuration only; it isn't designed for secret material. See [[12. Containers — OCI OKE, Container Instances, OCIR]]'s "Managing OCIR images and security" section for the related kubectl-created registry secret mechanism for private OCIR pulls.*

---

### Q2
As a DevOps Engineer working on an OKE cluster, which file provides you access details to OKE cluster?

A. Kubernetes
B. Kubectl
C. Kube-proxy
D. Kubeconfig

**Answer: D** (selected correctly)

*Matches [[12. Containers — OCI OKE, Container Instances, OCIR]]'s "Accessing a cluster with kubectl" section and the hands-on `oci ce cluster create-kubeconfig --file ~/.kube/config` command run directly against `lab-oke-stack` earlier this session — generated via `oci ce cluster create-kubeconfig`, always lands at `$HOME/.kube/config` regardless of setup path (Cloud Shell vs. local install).*

---

### Q3
As a Cloud Engineer, you are asked to manage the OCI Container Registry, which hosts Docker container images. You are directed to delete all the images within a tenancy region that have not been pulled for over 72 hours to avoid billing charges for the storage space they consume. Which action should you perform to handle this requirement?

A. Periodically delete old, unused images using Docker CLI.
B. Set up local image retention policies to delete images automatically based on selection criteria.
C. Set up a global image retention policy to delete images automatically based on selection criteria.
D. For each old, unused image, select Delete Image from the Actions menu and confirm that you want to delete the image.

**Answer: C** (initially selected B — incorrect; corrected to C before submitting)

*The scenario's "within a tenancy region" scope is the tell — a global image retention policy applies to all repositories in a region by default. Verified against Oracle's docs directly (docs.oracle.com/en-us/iaas/Content/Registry/Tasks/registrymanagingimageretention.htm): the answer choices' term "local" is not the real OCIR term — Oracle's actual second policy type is called **custom**, scoped to specific repositories explicitly added to it (one custom policy per repo at a time), not "local." See [[12. Containers — OCI OKE, Container Instances, OCIR]]'s "Lifecycle/retention policies" section for the corrected terminology.*

---

### Q4
You work as a DevOps engineer and are responsible for managing the container images stored in your team's Oracle Cloud Infrastructure Registry (OCIR) repository. One of your team members accidentally deletes an important container image from the repository. You need to recover the image as soon as possible. How long do you have to undelete the image from OCIR before it is permanently deleted?

A. 72 hours
B. 24 hours
C. 48 hours
D. 96 hours

**Answer: C** (initially selected B — incorrect; corrected to C before submitting)

*Verified against Oracle's docs directly (docs.oracle.com/en-us/iaas/Content/Registry/Tasks/undelete-image.htm): "You can undelete an image you've previously deleted, for up to 48 hours after you deleted it. After that time, the image is permanently removed from Container Registry." Restore via `oci artifacts container image restore --image-id <image-ocid>`. See [[12. Containers — OCI OKE, Container Instances, OCIR]]'s "Managing OCIR images and security" section for the corresponding delete/undelete coverage.*

---

## Result: Passed — 100% (4/4)

Two of four questions had an incorrect answer selected initially and were
corrected before submitting (Q1: ConfigMap → Secret; Q3: local → global
retention policy) — worth a review pass on OCIR retention policy
terminology (Global vs. Custom, not "Local") and Kubernetes Secret vs.
ConfigMap scope before the real exam.

---

## Skill Check: Deliver Infrastructure-as-code

### Q1
Your team lead has provided you with a Terraform configuration which includes variables (but not limited to) OCIDs, IP addresses, and CIDR blocks. You have been tasked with using Resource Manager to provision many versions of the environment with different values for some of these variables. Which two statements are true? **Select TWO correct answers.**

A. For each environment, you need to create a terraform.tfvars file that defines the variables. When you provision each stack, supply the respective variables file.
B. Resource Manager can automatically populate some variable values.
C. For each environment, you need to create a separate Terraform configuration with variables replaced by literals.
D. When you provision a stack, Resource Manager provides fields in the console to define all variables.
E. A schema document can be used to declare each of these environments and define the variables for each of them.

**Answer: B, D** (selected correctly)

*Directly matches the hands-on Resource Manager work done this session with `lab-network-stack`/`lab-nsg-stack`/`lab-func-stack` — the Configure Variables Console screen (option D) and Resource Manager's ability to auto-derive some OCID-type values via native pickers/data sources (option B). Option A describes the local-Terraform `.tfvars` workflow used for `lab-private-network-stack` onward, not Resource Manager's own variable-input model — a real, exam-relevant distinction between the two workflows this session used both of.*

---

### Q2
Which feature of the OCI Resource Manager service will you use to differentiate between the real-world state of your infrastructure and the stack's last executed configuration?

A. View State
B. Diff Detection
C. Apply or Import State
D. Drift Detection

**Answer: D** (selected correctly)

*Compares real-world provisioned infrastructure against the stack's last-executed Terraform configuration, surfacing manual/out-of-band changes made outside Terraform. Distinct from Apply (runs config forward) and Import State (brings existing resources under Terraform management) — drift detection diagnoses divergence, it doesn't fix it. Note "Diff Detection" (option B) is a plausible-sounding distractor, not the real Oracle term. See [[8. Management and Governance — OCI Resource Manager, OS Management Hub, Observability]]'s "Infrastructure as code" section, now expanded with this precise definition.*

---

### Q3
As a DevOps Engineer you have created a Terraform configuration for an infrastructure automation project on the OCI platform. You have been tasked with using OCI Resource Manager to automate the process of provisioning your OCI resources. Which two things happen when you apply Terraform configuration? **Select TWO correct answers.**

A. Terraform corrects formatting errors in your configuration.
B. Terraform makes any infrastructure changes defined in your configuration.
C. Terraform updates the state file with any configuration changes it made.
D. Terraform gets the plugins that the configuration requires.
E. Terraform destroys and recreates all your infrastructure from scratch.

**Answer: B, C** (selected correctly)

*Directly observed dozens of times this session across every `terraform apply` run in `terraform/` — infrastructure changes applied, `.tfstate` updated to match. The three distractors each belong to a different command: A is `terraform fmt`, D is `terraform init`, E is `terraform destroy` (a normal `apply` can still force a full resource *replacement* for a single resource when a change requires it — e.g. adding `nsg_ids` forced `lab-oke-stack`'s node pool to recreate — but that's targeted replacement, not "all infrastructure from scratch").*

---

### Q5
You are a DevOps engineer and as part of hybrid cloud infrastructure automation for a new project, you have been tasked to create Terraform stacks using Oracle Cloud Infrastructure (OCI) Resource Manager. Which two statements about Terraform are **FALSE**? **Select TWO correct answers.**

A. You configure multiple provider instances with the help of an alias.
B. Terraform CLI versions and provider versions are independent of each other.
C. Terraform is an IaaS.
D. Resource names in Terraform are provider specific.
E. Terraform codifies cloud APIs into declarative configuration files.

**Answer: C, D** — confirmed by MyLearn's own grading (initially selected A, C — A was marked incorrect; corrected pair per the grader is C and D)

*A real, non-obvious trap in the wording of D — worth understanding exactly why it's false, not just memorizing it: Terraform's `resource "<TYPE>" "<NAME>" {}` syntax has two separate naming layers. The resource **type** (e.g. `oci_core_vcn`, `oci_containerengine_cluster`) genuinely is provider-namespaced — this session's code used the `oci_` prefix on every single resource. But the resource **name** (e.g. `"lab_vcn"` — the local identifier you invent to reference the resource elsewhere in config) is entirely arbitrary, chosen by the author, and has nothing to do with the provider. D conflates these two layers — "resource names" (plural, generic) reads as the type prefix, but Terraform's own docs distinguish type from name precisely because the name is never provider-specific.

C ("Terraform is an IaaS") is false for a category reason: Terraform is IaC (Infrastructure as **Code**) tooling — it calls a provider's APIs to create/manage infrastructure, but provides no infrastructure of its own. IaaS (Infrastructure as a **Service**, e.g. OCI Compute) means the provider hosts infrastructure you consume; Terraform hosts nothing — stopping Terraform doesn't remove any resources it created, since it was never the thing running them.

A ("alias") and B (CLI/provider version independence) are both **true**, confirmed directly from this session's own `main.tf` files (`provider "oci" { alias = "home" }` used in `lab-storage-stack`/`lab-oke-official-module-stack`; `required_version` and `required_providers { oci = { version = ... } }` are separate, uncoupled fields in every stack) and cross-checked against HashiCorp's own docs on CLI/provider version independence before submitting.*

---

## Result: Not fully recorded

Q4 was never captured (this deck jumps Q3 → Q5), and no final pass/fail
score or percentage was recorded for this skill check — unlike the other
three. Q5 is confirmed as a MyLearn-graded miss (initially selected A, C;
corrected to C, D). Flagged here rather than guessed — if this skill check
is retaken, capture the full result and all five questions.

---

## Skill Check: Design Scalable and Elastic Solutions for High Availability and Disaster Recovery

### Q1
Which are the two main metrics to measure the effectiveness of a Disaster Recovery setup? **Select TWO correct answers.**

A. Mean Time to Recover (MMTR)
B. Minimum Time to Recover (MITR)
C. Recovery Point Objective (RPO)
D. Recover Time Objective (RTO)

**Answer: C, D** (selected correctly)

*RPO (how much data loss is acceptable — how far back in time) and RTO (how long the outage can last before recovery) are the standard pair of DR-effectiveness metrics, already the backbone of the design reasoning in [[Lab 2 - OCI Architect Pro Exam - HADR Design]] — e.g. that lab's RPO-near-zero requirement is exactly what justified choosing Data Guard over backup-only for the database tier. A and B are not standard DR-effectiveness terminology.*

---

### Q2
Which Disaster Recovery strategy provides data protection and availability for Oracle Database by maintaining an exact physical replica of the production copy at a remote location that is open read-only while replication is active?

A. Physical Standby
B. Active Data Guard
C. Golden Gate
D. Oracle Streams

**Answer: B** (selected correctly)

*Verified against Oracle's docs (blogs.oracle.com/ebstech and database-heartbeat.com corroborating). A real licensing distinction, not just naming overlap: a plain **Physical Standby** can be opened read-only, but only if redo apply is stopped first — replication and read-only access are mutually exclusive without the add-on. **Active Data Guard** is the licensed option that specifically allows read-only access **while redo apply keeps running simultaneously**. The question's exact phrasing ("open read-only while replication is active") is the tell that distinguishes B from A. See [[6. Databases — OCI Database, NoSQL, Caching, DR]]'s "Availability, read scale, and recovery" table, now updated with this distinction.*

---

### Q3
Which two statements about availability domains (AD) are true? **Select TWO correct answers.**

A. They provide high availability for application resources within a fault domain.
B. One region can have only one AD.
C. A regional subnet can be shared between two ADs.
D. Multiple ADs will never share physical infrastructure.

**Answer: C, D** (selected correctly)

*A's relationship is inverted — the real hierarchy is Region → Availability Domains → Fault Domains, so it's fault domains that isolate *within* an AD, not ADs providing HA within a fault domain. B is false as an absolute claim since region AD-count varies (1 or 3 depending on the region). C matches this session's own hands-on work directly — `lab-network-stack`'s subnet is regional, spanning every AD in the region, exactly as shown in the three-tier HA diagram in [[9. Networking — OCI VCN, DRG, Gateways, Load Balancers]]. D is the core definition of an AD: physically isolated data center with independent power/cooling/networking.*

---

### Q4
How many Fault Domains does one Availability Domain contain?

A. Two
B. Three
C. Four
D. One

**Answer: B** (selected correctly)

*A fixed number, not something that varies — every AD always has exactly 3 fault domains, regardless of region or AD count. This is why 3-way spread patterns show up repeatedly across OCI HA designs (e.g. the three-tier reference diagram in [[9. Networking — OCI VCN, DRG, Gateways, Load Balancers]]). See [[3. Compute — OCI Compute, Instance Pools, Load Balancers, Volumes]]'s "High availability and scaling" section, now updated with this exact count.*

---

### Q5
Which three key elements should be considered when designing high availability architecture? **Select THREE correct answers.**

A. Scalability
B. Monitoring
C. Redundancy
D. Failover
E. Virtualization

**Answer: B, C, D (Monitoring, Redundancy, Failover)** — selected A, C, D
(Scalability instead of Monitoring); this was the one miss on this skill
check (4/5 overall).

*Corrects my own in-session reasoning: I argued Monitoring was merely a
supporting/observability concern rather than a core HA pillar, and treated
Scalability as one of the three — MyLearn's grading says the opposite.
Oracle's framing here treats **Monitoring** (detecting failures/performance
issues in real time) as a first-class HA design pillar alongside
**Redundancy** (duplicating critical components so backups exist) and
**Failover** (the mechanism for switching to that backup — the Layer 1/Layer
2 Switchover-Failover distinction already worked out in
[[Lab 2 - OCI Architect Pro Exam - HADR Design]]). Scalability is a related,
important design concern but wasn't one of *these three* per this question's
intended framing — worth remembering that "important to HA" and "one of the
three canonical HA pillars this specific question wants" aren't always the
same list.*

---

## Result: 4/5 (80%)

Only miss was Q5 (Monitoring vs. Scalability as a core HA pillar) — worth a
review pass on Oracle's specific framing of HA design pillars
(Redundancy/Failover/Monitoring) before the real exam, since it doesn't
exactly match the more generic "scalability + resilience" framing that
feels intuitive coming from general cloud-architecture reasoning.

---

## Skill Check: Architect Security Solutions

### Q1
Which type of rule do you need to configure in OCI WAF to protect your web applications from various types of threats such as SQL injection, cross-site scripting, and HTML injection?

A. Bot Management
B. Rate Limiting rule
C. Protection rule
D. Access control rule

**Answer: C** (selected correctly)

*Matches [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]]'s WAF taxonomy directly — protection rules are the Input-Injection Attacks category (SQLi, XSS, LFI, RCE), distinct from access control rules (allow/deny/challenge by IP/geo/header/method) and Bot Management/rate limiting (the Bot & Automation and Layer 7 Volumetric & Abuse categories respectively). The question's three named threats (SQLi, XSS, HTML injection) are all squarely Input-Injection — the tell pointing straight at Protection rule.*

---

### Q2
Which statement best explains why a dynamic group is needed for Certificate Authority creation in OCI Certificate service?

A. A dynamic group is necessary to manage the Certificate Authority's revocation list.
B. A dynamic group is necessary to create TLS certificates after the Certificate Authority is created.
C. A dynamic group is not necessary for creating a Certificate Authority.
D. A dynamic group is necessary to allow the Certificate Authority to make API calls to vault or object storage services.

**Answer: D** (initially selected B — incorrect; corrected to D before submitting)

*A real, live-confirmed fact, not just a plausible-sounding option: a genuine tenancy Console screen showed a dynamic group named `OCI-SM-CA-DG`, described as "Dynamic Group for the Certificate Authority" — proof the CA itself needs resource-principal-style access to call other OCI services (Vault/KMS specifically, to reach its signing key) on its own behalf, the same pattern used for compute instances/Functions accessing buckets. B describes an unrelated, not-quite-coherent relationship (a dynamic group needed by a human to create certs afterward). This is the exact same unresolved authorization gap `terraform/LABS.md`'s `lab-mymagnet-stack` entry documents at length: real CA creation attempts against a real KMS key failed with "Authorization failed... Key Id..." even after two different IAM policy grants — a live, hands-on confirmation of the concept this question tests, not just abstract terminology. See [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]]'s dynamic-group-for-CA note.*

---

### Q3
Which Oracle Cloud Service provides restricted and time-limited secure access to resources that don't have public endpoints?

A. SSL certificate
B. Bastion
C. Load balancer
D. Internet Gateway

**Answer: B** (selected correctly)

*Matches [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]]'s "OCI Bastion service vs. a self-managed bastion host" section directly — restricted, time-limited (session-bound) secure access to private resources with no public endpoint, without exposing them via a public IP/jump host of your own.*

---

### Q4
Suppose you have a network firewall policy with two decryption rules and three security rules, each with a unique priority number. A packet arrives at the firewall, and the firewall inspects it according to the policy rules. Which scenario occurs?

A. The firewall evaluates the security rules first, then evaluates the decryption rules, and drops the packet if no rule matches the packet information.
B. The firewall evaluates the decryption rules first, applies the specified rule action if a match is found, and drops the packet if no decryption rule matches the packet information.
C. The firewall evaluates the decryption rules first, applies the specified rule action if a match is found, and then evaluates the security rules in priority order. If a security rule matches, the specified rule action is applied and no further rules are evaluated. If no security rule matches, the packet is dropped.
D. The firewall evaluates the security rules first, applies the specified rule action if a match is found, and then evaluates the decryption rules in priority order. If a decryption rule matches, the specified rule action is applied and no further rules are evaluated. If no decryption rule matches, the packet is dropped.

**Answer: C** (initially selected D — incorrect; corrected to C before submitting)

*Directly contradicts the four-stage pipeline documented in [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]]'s "How the Network Firewall processes every packet" section: **Decryption Rules evaluate first** (so encrypted threats are inspectable before anything downstream looks at them), **then Security Rules** (which drop unmatched traffic — the firewall's own internal default-deny), then Tunnel Inspection, then NAT last. D reverses stages 1 and 2. C is the only option matching the documented order, including the correct default-deny behavior at the security-rules stage ("if no security rule matches, the packet is dropped").*

---

### Q5
Which statement is MOST accurate about Oracle Cloud Infrastructure (OCI) Dedicated Key Management Service (DKMS)?

A. DKMS offers a lower level of security compared to a private vault.
B. DKMS requires using OCI APIs for all cryptographic operations.
C. DKMS offers a shared HSM partition managed by Oracle.
D. DKMS allows full control over keys and the underlying HSM partitions.

**Answer: D** (initially selected C — incorrect; corrected to D before submitting)

*Inverts the core differentiator documented in [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]]'s "Dedicated Key Management" section: Dedicated KMS's first named benefit is explicitly **"Full Control"** — a fully managed, **single-tenant** HSM partition with exclusive access, the opposite of a shared partition. C describes the regular (`DEFAULT`) shared-vault model, not Dedicated KMS's whole point. B is also wrong — Dedicated KMS's differentiator is industry-standard interfaces like **PKCS#11** specifically so applications can talk directly to the HSM *without* going through OCI APIs, per the same section.*

---

## Result: Passed — 100% (5/5)

Three of five questions had an incorrect answer selected initially and were corrected before submitting (Q2: B → D; Q4: D → C; Q5: C → D) — a 40% initial-miss rate despite the final 100%, and all three misses were on material already written up in Note 5 before taking this skill check. Added to the certification plan's "Top 10 items to review" list: the Network Firewall pipeline order (Decryption → Security → Tunnel Inspection → NAT), Dedicated KMS's single-tenant/full-control value prop (not shared), and the dynamic-group-for-CA purpose — the last one doubling as live confirmation of the exact concept behind `lab-mymagnet-stack`'s still-unresolved Certificate Authority authorization bug.

---

## Skill Check: Autonomous Database

*Prior attempt on this skill check showed "Highest score: 40%" in the playlist sidebar before this retake — see [[6. Databases — OCI Database, NoSQL, Caching, DR]] for the full underlying notes.*

### Q1
Which three are inputs provided when provisioning an Autonomous Database?

A. Deployment type
B. Name of superuser
C. Network access type
D. Compute model and shape
E. Workload type

**Answer: A, C, E** (attempt 1: selected B, C, D — incorrect; attempt 2: corrected to A, D, E — still incorrect, D flagged wrong; final correct answer is A, C, E)

*Platform feedback, verbatim: "While provisioning in the Console, you provide the display name, type of network access, type of workload, the type of deployment, version, license type, encryption type, etc." — **Compute model and shape (D) is NOT one of the intended three**, contradicting my own first read of this question. [[6. Databases — OCI Database, NoSQL, Caching, DR]] does correctly document compute model as chosen at provisioning and locked afterward (confirmed separately during the Cloning demo) — that fact isn't wrong, but it isn't one of the three inputs *this specific question* is built around. The real three are deployment type, network access type, and workload type. **A genuine, confirmed miss** — flagged for the Top 10 review list. Worth double-checking Note 6's provisioning section doesn't overstate compute model's centrality relative to network access type in this specific "which inputs" framing.*

---

### Q2
Which two of these are supported deployment options for an Autonomous Database?

A. Azure HPC
B. Dedicated Exadata infrastructure in AWS
C. Oracle Dedicated Region Cloud@Customer
D. OCI Public Cloud

**Answer: C, D** (selected correctly)

*A and B are fabricated distractors — Autonomous Database has no native deployment option on Azure or AWS infrastructure. **Trick worth flagging**: this question's four answer choices only surface 2 of the **4 real** documented deployment options ([[6. Databases — OCI Database, NoSQL, Caching, DR]]'s "Autonomous Database deployment options — four, not two" section: Serverless, Dedicated, Exadata Cloud@Customer, and Dedicated Region Cloud@Customer). "OCI Public Cloud" as an answer choice is not itself a named Oracle deployment-option term — it's a loose stand-in for Serverless/Dedicated running in a standard public OCI region, used here purely to distinguish from the on-premises Cloud@Customer option. Don't let this question's simplified two-option framing overwrite the real four-option taxonomy when studying — Exadata Cloud@Customer and Serverless-vs-Dedicated distinctions are still real, separately examinable facts this question doesn't test.*

---

### Q3
Which workload type should you choose while provisioning an Autonomous Database for a supply chain customer that needs to purpose the database, to record daily transactions and then run an EOD job as part of data consolidation?

A. Autonomous Data Warehouse
B. Autonomous Transaction Processing
C. Autonomous Blockchain Database
D. Autonomous JSON Database

**Answer: B** (selected correctly)

*Platform feedback, verbatim: "Workload types are ATP, ADW, AJOD, APEX" — note the platform's own feedback text spells the JSON workload type **"AJOD"** here, vs. **"AJD"** used consistently in [[6. Databases — OCI Database, NoSQL, Caching, DR]] — likely a typo in MyLearn's own copy rather than a different real service, but flagging the naming variance in case it recurs. **Autonomous Blockchain Database (C) is a fabricated distractor** — not one of the real four workload types (ATP/ADW/AJD/APEX). Recording daily transactions is textbook OLTP; the EOD consolidation job doesn't push this to ADW — ATP is designed to handle mixed transactional + light batch/reporting workloads without a separate warehouse.*

---

### Q4
Which two statements about Autonomous Database provisioning are true?

A. Autonomous Database is provisioned as a pluggable database.
B. Customer configures and manages the Exadata hardware before they can provision the Autonomous Database.
C. Autonomous Database is automatically provisioned in Oracle-managed Exadata hardware.
D. Autonomous Database is provisioned in Oracle Shards configured with high availability and fault tolerance.

**Answer: A, C** (attempt 1: selected C, D — incorrect; attempt 2: corrected to A, C — correct)

*Platform feedback, verbatim: "Autonomous Database is provisioned in Exadata hardware and each autonomous database is a pluggable database following multitenant architecture." **D is a fabricated-scope distractor**: it describes Globally Distributed Autonomous Database (sharding), a separate, opt-in service — NOT what happens automatically during standard Autonomous Database provisioning (see [[6. Databases — OCI Database, NoSQL, Caching, DR]]'s "Globally Distributed Autonomous Database — sharding architecture" section). **B is also wrong** and directly contradicts the "fully managed" premise — Oracle always owns/manages the Exadata hardware layer, in both Serverless and Dedicated deployment; even Dedicated's isolation is at the logical (ACD/ADB) level, not physical hardware control. **Real architectural fact confirmed by this question**: every Autonomous Database instance, regardless of deployment mode, runs on Exadata infrastructure — the Serverless/Dedicated distinction is about who owns/manages that Exadata (shared multi-tenant vs. a dedicated Exadata Infrastructure resource), not whether Exadata is used at all.*

---

### Q5
Which are the three allowed network access configurations available for Autonomous Database on shared infrastructure?

A. Private endpoint access only
B. Secure access from everywhere
C. Access only from OCI peered VCNs
D. Secure access from allowed IP and VCNs only

**Answer: A, B, D** (attempt 1: selected A, C, D — incorrect; attempt 2: corrected to A, B, D — correct)

*Platform feedback, verbatim: "Private endpoint access only, Secure access from allowed IP and VCNs only, Secure access from everywhere are the three network access types available for you to choose when provisioning Autonomous Database in shared infrastructure." Matches [[6. Databases — OCI Database, NoSQL, Caching, DR]]'s Serverless Provisioning network access tiers exactly. **"Access only from OCI peered VCNs" (C) is a fabricated distractor** — not one of the three real named tiers; don't confuse it with the real "allowed IPs and VCNs" tier (D), which does restrict by VCN among other criteria but isn't phrased or scoped as "peered VCNs only."*

---

## Result: Passed — 80% (4/5)

One question (Q1) had a **confirmed, uncorrected miss**: selected "Compute model and shape" instead of "Network access type" as one of the three core provisioning inputs, even after a first correction attempt. Three other questions (Q2, Q4, Q5) each involved at least one fabricated-but-plausible distractor mixed among real OCI concepts — see the "Recurring exam pattern" note at the top of this file and [[OCI Architect Professional Tips]] for the consolidated study strategy against this. This is a real, substantial improvement from the prior attempt's "Highest score: 40%." Added to the certification plan's "Top 10 items to review" list: the exact three Autonomous Database provisioning inputs (deployment type, network access type, workload type — NOT compute model/shape), and a reminder to re-verify Note 6's provisioning section framing against this platform feedback.

---

## Official Prep Workshop Sample Questions (Oracle University, "Prepare for OCI Architect Professional Certification")

*Source: MyLearn course [163275](https://mylearn.oracle.com/ou/course/prepare-for-oracle-cloud-infrastructure-architect-professional-certification/163275/273240), Part 2 transcript. Presented by instructor Samvit Mishra (Senior Manager, Oracle University), explicitly framed as **sample questions emulating the test format** — not real exam questions — used to teach the keyword-identification and elimination strategy. One question per exam domain. Distinct from the skill-check questions above (those are per-module MyLearn skill checks with your own answer attempts; these are Oracle's own worked examples with the instructor's reasoning, no attempt/miss data since you didn't answer them live).*

### Q1 — Architect High Availability and Disaster Recovery Solutions
Your organization runs a critical e-commerce application in an OCI region. Due to an unexpected natural disaster affecting the primary region, you need to quickly switch operations to a disaster recovery region with minimal downtime. Which OCI Full Stack Disaster Recovery feature helps achieve this?

A. Manual reconfiguration of DNS and resource settings
B. Manually creating snapshots of individual resources
C. Writing custom scripts for disaster recovery workflows
D. Automated failover of the complete application stack to the DR region

**Answer: D**

*Instructor's reasoning: the scenario's keyword is "minimal downtime." Options A–C all describe manual effort (reconfiguration, snapshots, custom scripts), which directly contradicts minimal downtime. Full Stack DR's actual value proposition is automating disaster recovery across the entire application stack — the keyword in D ("automated failover of the complete application stack") is the direct match.*

### Q2 — Architect Cloud-Native Solutions
As a cloud architect, you are designing a secure solution for managing and deploying containerized applications on OCI. Your development team needs to push and pull container images using Docker CLI with OCI Container Registry. Which authentication method should be used to securely access the private OCI Container Registry?

A. Configure a master encryption key in OCI Vault
B. Set up an SSH key pair
C. Generate and use an auth token
D. Use a JSON Web Token

**Answer: C**

*Instructor's reasoning: OCIR uses auth tokens for secure authentication when accessing private repositories through Docker CLI — generated from the user's OCI profile, used alongside the username during `docker login`. This provides secure, token-based authentication without exposing the OCI account password. Cross-reference: matches the real OCIR auth-token mechanism already documented in [[12. Containers — OCI OKE, Container Instances, OCIR]].*

### Q3 — Architect Security Solutions
You are designing a secure access solution for compute instances located in a private subnet. According to your organization's security requirements, these compute instances must not have direct access to the internet, and administrative access must be tightly controlled. Which statement correctly explains the purpose of OCI Bastion in this scenario?

A. It provides a public endpoint directly on the compute instance for remote administration.
B. It offers a secure, controlled public entry point for accessing resources located in a private subnet.
C. It functions as a firewall that blocks all external traffic to the private compute instances.
D. It acts as an additional authentication service that validates user credentials before instance access is granted.

**Answer: B**

*Instructor's reasoning: eliminate A ("public endpoint" directly on the instance defeats the "no direct internet access" requirement), C (Bastion isn't a firewall), and D (it isn't a credential-validation/auth service). OCI Bastion's real mechanism: secure access to private-subnet compute instances — without those instances needing public IPs or direct internet exposure — via a managed, controlled access mechanism (SSH port forwarding or session-based access) through a secure entry point.*

### Q4 — Architecting, Implementing, and Operating Databases in OCI
Your organization is evaluating Oracle Database Autonomous Recovery Service as part of its disaster recovery and backup strategy for Oracle databases. Which underlying technology is Oracle Database Autonomous Recovery Service built upon?

A. Oracle Data Guard
B. Oracle Recovery Manager (RMAN)
C. Oracle Zero Data Loss Recovery Appliance
D. Oracle GoldenGate

**Answer: C**

*Instructor's reasoning: a direct fact rather than an elimination exercise — Autonomous Recovery Service (ARS) is built on **Zero Data Loss Recovery Appliance** technology, delivering automated cloud-based backup/recovery designed for highly efficient backups, rapid recovery, and near-zero data loss protection. **Don't confuse this ARS (the general Oracle Database backup service covering Base DB, Exadata Database Service, Autonomous Database Dedicated, and multicloud) with Zero Data Loss Autonomous Recovery Service (ZRCV)** — the Autonomous-Database-specific, extra-cost, sub-second-RPO tier documented separately in [[6. Databases — OCI Database, NoSQL, Caching, DR]]. Same underlying ZDLRA technology lineage, but ARS and ZRCV are two distinct named services.*

### Q5 — Implementing Observability Solutions
Your organization uses OCI Connector Hub to move logs from OCI Logging to OCI Object Storage. To reduce storage consumption and keep only relevant data, you want to transfer only logs that contain error-level events. Which OCI Connector Hub feature should you configure to accomplish this requirement?

A. Agent configuration
B. Log filter task
C. Tags
D. IAM policies

**Answer: B**

*Instructor's reasoning: a **log filter task** in Connector Hub filters/processes logs before they're transferred to the target service (here, Object Storage) — configuring one ensures only error-level logs are forwarded, reducing storage and improving the relevance of what's retained. The other three options don't operate on log content/severity at all: agent configuration governs collection agents, tags are metadata/organization, and IAM policies control access — none of them filter by log level.*

## Test-taking strategy demonstrated across all five (see [[OCI Architect Professional Tips]] Section 1 for the full write-up)
- Identify the scenario's **keyword(s)** first — each question above hinges on one or two words ("minimal downtime," "private," "error-level events") that immediately eliminate options not addressing that specific constraint.
- **Process of elimination** beats trying to recall the "right" answer directly — three of the five worked examples (Q1, Q2, Q3) are explicitly solved by ruling out wrong options rather than recognizing the correct one on sight.
- Watch for options that **sound plausible but describe manual/partial mechanisms** when the scenario asks for something automated/complete (Q1's A–C), or that invoke a real OCI concept in the wrong role (Q3's firewall/auth-service mischaracterizations of Bastion) — the same fabricated-plausible-distractor pattern already flagged at the top of this file for the skill-check questions.

---

## Practice Exam 997-26 (MyLearn, 50 questions, timed, live attempt)

*Source: [Practice Exam: Oracle Cloud Infrastructure Architect Professional](https://mylearn.oracle.com/ou/course/practice-exam-oracle-cloud-infrastructure-architect-professional/163237/271344) — a full 50-question timed mock exam, distinct from the per-module skill checks and the workshop's 5 sample questions above. Captured live, question by question, as taken; correct answers verified against Oracle's official documentation where not already covered in these notes (cited inline), since this practice exam doesn't show correct-answer explanations inline the way skill checks do.*

### Q1 — OKE / kubectl cluster access (multi-select, choose TWO)
You are configuring access to an OCI Container Engine for Kubernetes (OKE) cluster using kubectl. Which TWO statements are correct regarding the configuration required to access the cluster?

A. To access the cluster using kubectl, you have to set up a Kubernetes configuration file for the cluster. The kubeconfig file by default is named `config` and stored in the `$HOME/.kube` directory.
B. You cannot set up Cloud Shell access to the cluster if the cluster's Kubernetes API endpoint has a private IP address.
C. When a cluster's Kubernetes API endpoint has a public IP address, you can access the cluster in Cloud Shell by setting up a kubeconfig file.
D. To access the cluster using kubectl, you have to set up a Kubernetes manifest file for the cluster. The kubeconfig file by default is named config and stored in the `$HOME/.manifest` directory.
E. Generating an API signing key pair is a mandatory step while setting up cluster access using a local machine if the public key is not already uploaded in the console.

**Your answer: B, C — Confirmed CORRECT**, verified directly against Oracle's docs (Setting Up Cluster Access / Accessing a Cluster Using Kubectl). Cloud Shell access to an OKE cluster requires a **public** Kubernetes API endpoint; a private endpoint blocks direct Cloud Shell access entirely (Bastion tunneling is the documented workaround, not covered by this question's options). A is a plausible-sounding near-miss — the real kubeconfig default location is `$HOME/.kube/config`, not what A/D describe once you check A's own wording matches the real fact but wasn't selected as one of the two (only two answers required, and B+C are the ones the question is testing). D is a fabricated distractor (`$HOME/.manifest` isn't real). **Added to [[12. Containers — OCI OKE, Container Instances, OCIR]]'s "Accessing a cluster with kubectl" section.**

### Q2 — Compute / Instance Pool Autoscaling
An e-commerce company is running on OCI and many compute instances remain unused for most of the year except during Black Friday and Christmas. You suggest they use OCI's Autoscaling feature and present a slide showcasing its features. Which option is accurate in your presentation to the customer?

A. Autoscaling requires an instance pool as a prerequisite so that it can automatically adjust the number of compute instances in an instance pool.
B. During the cooldown period, OCI stops collecting monitoring metrics for the instance pool.
C. When an instance pool scales in, instances are terminated in this order: the number of instances is balanced across availability domains, and then balanced across fault domains. Finally, within a fault domain, the **newest** instance is terminated first.
D. Autoscaling does not rely on performance metrics such as CPU utilization that are collected by OCI Monitoring service to trigger Autoscaling events.

**Your answer: C — INCORRECT.** Verified directly against Oracle's Autoscaling docs: the real termination order is AD-balance → FD-balance → **oldest** instance terminated first within a fault domain, not newest. This is a single-word distractor swap on an otherwise-correct-sounding option — a real trap pattern for this exam (see [[OCI Architect Professional Tips]]'s fabricated-distractor writeup). **B and D are also false**: cooldown does not stop metric collection (it only suppresses new scaling actions), and autoscaling absolutely does rely on Monitoring-service metrics like CPU utilization as triggers. **A's framing is backwards/confused** — an instance pool is the thing autoscaling is configured against, not a "prerequisite" in the sense implied; not the intended correct answer either. None of the four options as tested is fully correct except C's structural framing (AD→FD→oldest), with only the "newest" word being wrong — **added to [[3. Compute — OCI Compute, Instance Pools, Load Balancers, Volumes]]'s "High availability and scaling" section with the corrected fact.**

### Q3 — Serverless / OCI Vault + Oracle Functions
Your organization is developing serverless applications with Oracle Functions. Many of these functions will need to store state data in a database which will require the use of appropriate credentials. However, your corporate security standards mandate the encryption of secret information, such as database passwords. As a solutions architect, which approach would you direct your team to follow to satisfy this security requirement?

A. Use the OCI Vault service to auto-encrypt the password, then set an application-level configuration variable to reference the auto-decrypted password inside your function container.
B. Leverage application-level configuration variables to store passwords because they are automatically encrypted by Oracle Functions.
C. Encrypt the password using the OCI Vault service, then decrypt this password in your function code with the generated key.
D. Use the OCI Console to enter the password in the function configuration section in the provided input field.

**Your answer: A — likely INCORRECT** (my assessment from Oracle documentation, not from an in-app answer key — flagged as such; re-verify against the exam's own grading/summary screen if you get one). Verified against Oracle's own "Using Key Management To Encrypt And Decrypt Configuration Variables" guidance for Oracle Functions: there is **no "auto-decrypt" mechanism** where a config variable transparently references a decrypted secret. The real, documented flow is (1) encrypt the password **offline**, outside the function, using a Vault-managed key, (2) store the **ciphertext** as a config variable, (3) **the function's own code calls the Vault/KMS Decrypt API at runtime** to get the plaintext back. That matches **C** exactly ("decrypt this password in your function code with the generated key"), not A's "auto-decrypt" framing. **B is false** (Oracle Functions does not auto-encrypt config variables), **D is false** (plaintext passwords in Console config fields directly violates the stated encryption mandate). **Added the corrected mechanism to [[14. Serverless — OCI Functions, Events, API Gateway]]'s "OCI Functions architecture" section.**

### Q4 — Cloud-Native / API Gateway DDoS mitigation
As a Solutions Architect, one of your cloud-native developers has written a web service for your company. They have configured the OCI API Gateway service to expose the HTTP backend. However, your security team has indicated that the web service must handle Distributed Denial-of-Service (DDoS) attacks. You are time-constrained and you need to ensure that this requirement is implemented as soon as possible. What should be done in this scenario?

A. Create and deploy an Oracle Integration Cloud flow to implement a DDoS attack mitigation for that HTTP backend.
B. Configure the Virtual Cloud Network that hosts the API Gateway to enable IP address segregation for that HTTP backend to mitigate DDoS attacks.
C. Create and deploy an Oracle Function that implements DDoS attack mitigation to be invoked from the API Gateway for that HTTP backend.
D. Direct the developer to immediately update the web service to implement DDoS mitigation logic.
E. Configure rate limiting for that HTTP backend in the API Gateway.

**Your answer: B — INCORRECT.** Verified directly against Oracle's API Gateway docs: **"IP address segregation" is not a real OCI VCN/API Gateway feature** — a fabricated-sounding distractor. The correct answer is **E**: OCI API Gateway has a **native rate-limiting request policy**, configured directly on the deployment/route — the fastest, no-new-service, no-code-change mitigation available, which is exactly what "time-constrained... as soon as possible" is testing for. A, C, and D all require building/deploying something new (an Integration Cloud flow, a custom Function, or a code change) — slower and heavier than flipping on an existing gateway policy. **Added to a new "API Gateway request policies" section in [[14. Serverless — OCI Functions, Events, API Gateway]].**

### Q5 — Security / OCI Certificates service automation
OracleRetail Inc. is an online marketplace that wants to enhance the security of its customer transactions by ensuring encrypted connections using TLS on OCI. To prevent service disruptions due to expired certificates, they decide to implement OCI Certificates service for automated certificate provisioning and renewal. What is a key advantage of automating TLS certificate management in OCI?

A. Minimizes the risk of manual errors during certificate issuance and renewal
B. Ensures that applications do not require regular security updates
C. Eliminates the need for access control and authentication mechanisms
D. Increases the speed of data transmission by optimizing encryption protocols

**Your answer: A — Confirmed CORRECT** by elimination alone, no external verification needed: B, C, and D each make a false absolute claim (automating certificate renewal has no bearing on whether apps need security updates, doesn't eliminate access control/auth, and doesn't touch transmission speed/protocol optimization). A is the only option describing what certificate automation actually does — remove human error from a recurring operational task.

### Q6 — Networking / VCN subnet deletion blocked by an attached VNIC
You are part of a project team working in the development environment created in OCI. You realize that the CIDR block specified for one of the subnets in a Virtual Cloud Network (VCN) is not correct and want to delete the subnet. While deleting you get an error indicating that there are still resources that you must delete first. The error includes the OCID of the VNIC that is in the subnet. Which action should be taken to troubleshoot this issue?

A. Use OCI CLI to delete the subnet using the `--force` option.
B. Use OCI CLI to call the "network vnic" and "compute vnic-attachment" operations to find out the parent resource of the VNIC.
C. Use OCI CLI to delete the VNIC first and then delete the subnet.
D. Copy and paste the OCID of the VNIC in the search box of the OCI Console to find out the parent resource of the VNIC.

**Your answer: D — likely INCORRECT** (my assessment from Oracle's official VCN Troubleshooting doc, not from an in-app answer key — re-verify against the exam's own grading/summary if available). Oracle's documented method is the **CLI**, not the Console search box: `oci network vnic get --vnic-id <VNIC_OCID>` returns the VNIC's `display-name`, which reveals the parent resource (e.g. `"VNIC for LB ocid1.loadbalancer..."` for a load balancer, or a mount-target-style name for File Storage) — matching **B**'s framing ("use OCI CLI to call... operations to find out the parent resource") far more closely than D's Console-search-box approach. `--force` (A) isn't a real documented flag/practice for this, and you can't directly delete a service-managed VNIC (C) without first deleting/reconfiguring its parent resource — the VNIC is owned by that resource, not independently deletable. **Added a new "Troubleshooting: subnet/VCN deletion blocked by an attached VNIC" subsection to [[9. Networking — OCI VCN, DRG, Gateways, Load Balancers]] with the full documented remediation sequence.**

### Q7 — Networking / DNS Traffic Management, geo-routing
As a solution architect, you are designing a web application to be deployed across multiple OCI regions for a global audience. Your goal is that users from each region should access the application web servers deployed in their own geographical OCI location. Which OCI feature can be used to achieve this?

A. OCI Traffic Management IP Prefix steering policy
B. OCI Public Load Balancers
C. OCI Global Load Balancers
D. OCI Traffic Management GeoLocation steering policy

**Your answer: D — Confirmed CORRECT**, already documented in [[9. Networking — OCI VCN, DRG, Gateways, Load Balancers]] Section 7: Traffic Management steering policies make DNS answers based on policy, endpoint health, **geography**, ASN/path, or weighted distribution — geolocation-based steering is exactly the named mechanism for routing users to a region-specific deployment based on where they're connecting from. Load balancers (B) distribute traffic across backends within a region/endpoint, not across geographically separate deployments; "OCI Global Load Balancers" (C) isn't a real distinct OCI product name — likely a fabricated distractor; IP Prefix steering (A) is a real but different steering-policy type (routes by source IP/ASN block, not geography).

### Q8 — Security / OCI Vault KMS CLI, crypto vs. management endpoint
When trying to encrypt plaintext using CLI, the developer gets a Service Error running:
```
oci kms crypto encrypt --key-id ocid1.key.oc1.iad.bbptfrr5aaeuk.abuwcljt32arg6e6xlswgluvc52lnrtk62jq7jenfejfxlhb46nkav3zhsta --plaintext foobar --endpoint https://bbptfrr5aaeuk-management.kms.us-ashburn-1.oraclecloud.com
```
Which issue in the command caused the Service Error?

A. The plaintext needs to be in JSON form.
B. The user should pass the key version OCID instead of the key OCID.
C. The developer forgot to specify the region.
D. The developer has the wrong endpoint.

**Your answer: C — likely INCORRECT.** Already-documented fact in this same note file (Section on "Every vault exposes two distinct, separately-addressed API endpoints") makes this diagnosable directly: `oci kms crypto encrypt` is a **cryptographic (data-plane)** operation and requires the vault's **Cryptographic Endpoint** (`https://<vault-id>-crypto.kms.<region>...`); the command instead supplies a **Management Endpoint** (note the `-management.kms.` in the hostname) — the control-plane URL used for key lifecycle operations (create/rotate/disable), not crypto operations. That's **D**, not C. Region was never missing — it's present in both the key OCID's `.iad.` segment and the endpoint's `us-ashburn-1` substring. `--key-id` (option B's target) correctly takes the master key OCID as shown; a key-version OCID is a separate, optional `--key-version-id` flag, not a replacement. `--plaintext` (option A) takes a raw string, not JSON. **This exact endpoint-type mismatch was already documented in this file** (search "Every vault exposes two distinct" above) — added a direct practice-exam cross-reference confirming the trap.

### Q9 — Cloud-Native / definition of "a microservice"
A company is experiencing performance issues with its monolithic architecture for an e-commerce website. The software development team is considering implementing a new design approach to improve performance and scalability. In the context of software architecture, what is a microservice?

A. A style of design for enterprise systems based on a loosely coupled component architecture
B. A small program that represents discrete logic that executes within a well-defined boundary on dedicated hardware
C. A cloud-based service for testing and deploying microcode
D. A software framework for automating user interface testing

**Your answer: A — likely INCORRECT.** This is a definitional trap, not an OCI-specific fact: the question asks what **a** microservice is (the individual unit), not what microservices **architecture** is (the overall pattern). A's phrasing ("a style of design... loosely coupled component architecture") describes the architectural pattern as a whole. Oracle's own developer docs describe an individual microservice as having "a specific, well-defined responsibility," being **small**, and running in its own process — matching **B**'s phrasing ("a small program that represents discrete logic that executes within a well-defined boundary") far more precisely as the definition of one unit. C and D are both fabricated/irrelevant ("microcode" and "UI testing framework" have nothing to do with microservices). **Added this A-vs-B definitional distinction to a new section at the top of [[14. Serverless — OCI Functions, Events, API Gateway]].**

### Q10 — Networking / private subnet reaching a public-endpoint Autonomous Database (choose TWO)
You have deployed an application server in a private subnet in your VCN. For the database, you have provisioned an Autonomous Transaction Processing (ATP) serverless instance. However, you are unable to connect to the database instance from your application server. Which two steps would you need to enable this connectivity?

A. Add a stateful egress rule to the security list associated with your private subnet. Destination CIDR: 0.0.0.0/0, Protocols: All Protocols
B. Add a remote peering connection from your VCN to the ATP VCN.
C. Add an internet gateway to your VCN and add a route rule to your private subnet route table. CIDR: 0.0.0.0/0, Target: Internet Gateway
D. Create a NAT Gateway and add the following route rule to the route table of a private subnet. CIDR: 0.0.0.0/0, Target: NAT Gateway

**Your answer: A, D — Confirmed CORRECT**, verified against Oracle's own guidance: Autonomous Database (with a public endpoint) is one of the specific OCI services reachable through **either** NAT Gateway or Service Gateway when both exist in a VCN — and when both are available, the **more specific route wins, which is the NAT Gateway**. So the real fix is (1) a NAT Gateway with a `0.0.0.0/0` route in the private subnet's route table, plus (2) a stateful egress security-list rule permitting that outbound traffic — exactly D and A. B (remote VCN peering) is wrong because ADB isn't sitting in a peer VCN you control; C (adding an Internet Gateway to a **private** subnet) directly contradicts the subnet's own private status and isn't how private subnets reach public endpoints. **This is a real exception to the "prefer Service Gateway for Oracle services" general rule already in this repo — added the exception, with the NAT-Gateway-IP-as-connection-source caveat, to [[9. Networking — OCI VCN, DRG, Gateways, Load Balancers]]'s "NAT and service-gateway traps" subsection.**

---

## Practice Exam 997-26, attempt 2 (MyLearn, 50 questions, timed, 2026-09-25)

*Same exam as above, retaken. Option order is shuffled between attempts, so letters here refer to this attempt. Where a question repeats from attempt 1, the entry links back to it.*

### Q1 — Networking / subnet deletion blocked by a VNIC (repeat of attempt 1 Q6)
You are part of a project team working in the development environment created in OCI. You realize that the CIDR block specified for one of the subnets in a VCN is not correct and want to delete the subnet. While deleting you get an error indicating that there are still resources that you must delete first. The error includes the OCID of the VNIC that is in the subnet. Which action should be taken to troubleshoot this issue?

A. Copy and paste the OCID of the VNIC in the search box of the OCI Console to find out the parent resource of the VNIC.
B. Use OCI CLI to delete the VNIC first and then delete the subnet.
C. Use OCI CLI to delete the subnet using the `--force` option.
D. Use OCI CLI to call the "network vnic" and "compute vnic-attachment" operations to find out the parent resource of the VNIC.

**Your answer: D — likely CORRECT** (improved from attempt 1, where you chose the Console-search option). Same reasoning as attempt 1 Q6: Oracle's VCN troubleshooting doc uses the CLI, `oci network vnic get --vnic-id <VNIC_OCID>`, whose `display-name` names the owning resource, and `oci compute vnic-attachment list` for instance VNICs. A service-owned VNIC can't be deleted on its own (B), and `--force` (C) doesn't clear dependent resources. See [[9. Networking — OCI VCN, DRG, Gateways, Load Balancers]] ("Troubleshooting: subnet/VCN deletion blocked by an attached VNIC") and [[CLI Command Reference - OCI Architect Pro Study]].

### Q2 — Security / OCI Certificates automation (repeat of attempt 1 Q5)
OracleRetail Inc. is an online marketplace that wants to enhance the security of its customer transactions by ensuring encrypted connections using TLS on OCI. To prevent service disruptions due to expired certificates, they decide to implement OCI Certificates service for automated certificate provisioning and renewal. What is a key advantage of automating TLS certificate management in OCI?

A. Increases the speed of data transmission by optimizing encryption protocols
B. Ensures that applications do not require regular security updates
C. Eliminates the need for access control and authentication mechanisms
D. Minimizes the risk of manual errors during certificate issuance and renewal

**Your answer: D — CORRECT** (same as attempt 1). The other three make false absolute claims: automation doesn't change protocol speed, remove the need for app security updates, or replace access control. Related hands-on: the capstone's own OCI Certificates CA failure (a CA needs its own dynamic group to use its Vault key); see [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]].

### Q3 — Security / Vault secret version rollback
In OCI Secret Management within a Vault, you have created a secret and rotated the secret one time. The current version state shows: version 2 (latest) is Current, version 1 is Previous. In order to roll back to version 1, what should the administrator do?

A. From the version 2 (latest) menu, select "Rollback..." and select version 1 when given the option.
B. Create a new secret version 3 and set to Pending. Copy the contents of Version 1 into version 3.
C. Deprecate version 2 (latest). Create new Secret Version 3. Create soft link from version 3 to version 1.
D. From the version 1 menu, select "Promote to Current."

**Your answer: D — CORRECT.** A `PREVIOUS` secret version can simply be promoted back to current (Console "Promote to Current" on that version; CLI `oci vault secret update --current-version-number 1`). A invents a "Rollback…" action that doesn't exist; B works in effect but is needless extra work, and "copy contents" isn't how rollback is designed; C invents soft links between versions. **Added the rollback mechanism to [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]]'s secret-lifecycle bullets.**

### Q4 — Databases / Autonomous Recovery Service near-zero data loss
Which feature of Oracle Autonomous Recovery Service (RCV) helps achieve near zero data loss protection?

A. Full database backups performed once every quarter
B. Continuous archiving of redo logs to Recovery Service
C. Manual export of backups to Object Storage
D. Replication of block volumes across Availability Domains

**Your answer: D, then changed to B during the attempt** (the first pick, block volume replication, is the trap; the latest screenshot still showed D selected, so confirm the final submitted answer on the results page). **Correct: B.** Real-time data protection in Recovery Service (the Zero Data Loss tier) works by the protected database **continuously shipping redo** to the service, giving sub-second RPO. Block volume cross-AD replication is a Block Volume feature, not part of Recovery Service, and works at the disk level rather than on database redo. A and C are infrequent/manual and can't give near-zero loss. This was already in [[6. Databases — OCI Database, NoSQL, Caching, DR]] ("Enhanced tier: Zero Data Loss Autonomous Recovery Service"); added an exam-trap line there.

### Q5 — Databases / Autonomous Database logical corruption: restore vs. clone
A production Autonomous AI Database experiences logical corruption at 10:05 AM. Service must be restored quickly, and the corrupted state must remain available for investigation. Which approach should be used?

A. Perform a point-in-time restore on the production database to 10:04 AM
B. Restore only from a long-term backup, because standard backups cannot be used
C. Create a read-only clone from the current corrupted production database
D. Create a clone from a backup taken before 10:05 AM and leave production unchanged

**Your answer: A — likely INCORRECT. Likely correct: D.** An in-place point-in-time restore (A) brings service back but overwrites the corrupted state, violating the "remain available for investigation" requirement. A clone from a pre-10:05 backup (D) gives a clean database to serve from while the corrupted production database stays intact. C copies the corruption, so it doesn't restore service; B's premise is false (standard automatic backups support point-in-time recovery). **Added a restore-vs-clone line to [[6. Databases — OCI Database, NoSQL, Caching, DR]]'s clone-from-backup notes.**

### Q6 — Observability / Monitoring query: which field is the aggregation window
When defining a query for metric data in Monitoring, which field provides the time window for aggregating metric data points plotted on the metric chart?

A. Statistic
B. Interval
C. Namespace
D. Dimension

**Your answer: D — INCORRECT. Correct: B (Interval).** In MQL `CpuUtilization[5m]{resourceId = "…"}.mean()`, `[5m]` is the **interval** (aggregation window), `.mean()` is the **statistic** (aggregation function), `{…}` filters on **dimensions**, and the namespace (e.g. `oci_computeagent`) selects the metric's source. The capstone's live alarms use exactly this shape (`CpuUtilization[5m]{resourceId =~ "id1|id2"}.mean() > 80`). Already defined in [[8. Management and Governance — OCI Resource Manager, OS Management Hub, Observability]] ("Interval vs. Resolution"); no new note needed.

### Q7 — Containers / OCIR prerequisite for docker push and pull
You are a software developer working on a project that requires containerization of your application using Docker. Your company uses OCI Registry to store and manage Docker images. What is the prerequisite step you need to perform before pushing and pulling Docker images to and from OCI Registry using Docker CLI?

A. Master Encryption Key in OCI Vault
B. SSH key pair
C. Auth token
D. Docker registry secret

**Your answer: D — INCORRECT. Correct: C (Auth token).** `docker login <region-key>.ocir.io -u '<namespace>/<username>'` uses an **auth token** as the password (for federated users, `<namespace>/oracleidentitycloudservice/<username>`). A **docker-registry secret** (D) is the Kubernetes object that lets OKE pods pull private images; it is created *from* the auth token, so it's a later step for a different client. A Vault key (A) and SSH keys (B) play no part in registry auth. Live example: the capstone's Phase 3 image push is blocked on exactly this token. See [[12. Containers — OCI OKE, Container Instances, OCIR]].
