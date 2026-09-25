# OCI Architect Professional Tips — 1Z0-997-26

#certs #7_mystudy

**Companion reference:** [OCI_Architect_Professional_CheatSheet.html](OCI_Architect_Professional_CheatSheet.html) — a one-page visual service reference (Compute, Networking, Storage, Database, Security, Governance, Observability, Migration, AI/Multicloud) plus exam snapshot and domain weighting, styled the same way as your AWS SAA-C03 poster.

Unlike your AWS tips file, this isn't a refresh of old notes — it's a first pass, since this is a new cert for you rather than a recert. Treat it as a starting skeleton to add to as you go through labs.

---

## 1. The format is the biggest trap, not the content
**Correction, confirmed directly from Oracle University's own "Prepare for OCI Architect Professional Certification" workshop video (Samvit Mishra, Senior Manager, Oracle University) — supersedes the HPE claim below.** The exam is **multiple-choice only**: 90 minutes, 50 questions, 68% passing score. **No negative marking** — always answer, even a guess, rather than leaving a question blank. This is *not* a Hands-on Performance Exam with live lab tasks — that description (kept below struck through for history) does not match the 2026 exam as Oracle itself describes it in the official prep workshop.

~~This is a Hands-on Performance Exam (HPE): real lab tasks in a live OCI environment, scored per sub-task with partial credit, blended with multiple-choice. If a scenario asks for 9 configuration steps and you complete 7, you get credit for 7 — so don't skip a hard sub-task to save time, since partial credit rewards attempting everything over polishing fewer things.~~

**Test-taking strategy, straight from the workshop:**
- Read the question carefully and identify the **keywords/themes** first (the workshop's own worked examples hinge entirely on spotting a single keyword — e.g. "automated failover" vs. "manual reconfiguration," or "minimal downtime").
- Use **process of elimination** — read every option, discard obvious distractors first, especially when two options sound deceptively similar.
- **Mark for review and move on** if a question is taking too long — 90 minutes for 50 questions doesn't allow getting stuck. Return to marked questions after finishing the rest.
- **Always answer, even an intelligent guess** — no negative marking means a blank answer is strictly worse than any guess.

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
| Data Guard protection modes (general Oracle DB concept, not just Dedicated ADB) | 3 | Maximum Availability, Maximum Performance, Maximum Protection — **note**: the Dedicated ADB-specific "enable Autonomous Data Guard" screen only exposes 2 of these 3 (Max Availability, Max Performance) as pickable modes; Max Protection is a real Data Guard concept but not offered there — don't conflate the general 3-mode taxonomy with that specific screen's 2-mode subset |
| Globally Distributed ADB replication mechanisms | 2 | Oracle Data Guard (19c + 23ai), Raft Replication (23ai only) |
| Raft Replication factor choices | 3 | 3, 5, or 7 |
| Consumer group tiers — ATP/AJD | 5 | TPURGENT, High, Medium, Low (ADW gets only High/Medium/Low — 3, no TPURGENT) |
| Base Database Service backup destinations | 3 | Recovery Service, Object Storage, Local Storage (Local Storage does NOT survive DB System failure — the real trap) |
| Oracle Database 23ai named BaseDB features | 6 | AI Vector Search, Data Usercase Domains, Priority Transactions, True Cache, Rolling Patching, SQL Firewall |
| Autonomous Database Dedicated hard limits | 3 numbers | 12 ACDs per AVM Cluster; 200 ADBs per ACD (normally); 25 ADBs per ACD (with Data Guard enabled) |
| ARS protection policy tiers | 4 | Platinum (95 days), Gold (65 days), Silver (35 days), Bronze (14 days) |
| OCI Cache non-shard cluster node range | 1–5 nodes | 1 primary + up to 4 replicas |
| "What fully managed automates" (Autonomous vs. Base DB) | 4 | Backup, Patching, Upgrading, Tuning |
| IAM policy verbs (escalating privilege) | 4 | inspect → read → use → manage, strictly nested (each a superset of the one before). Verb-to-action mapping is resource-type-specific — don't assume "use" means the same concrete API calls across every service family. |
| Network Firewall packet-processing pipeline (exact order) | 4 stages | Decryption Rules → Security Rules (default-deny: unmatched traffic dropped) → Tunnel Inspection Rules (VXLAN-aware) → NAT Rules (last, only runs on already-allowed traffic) — this exact order was a confirmed skill-check miss (see [[MyLearn Skill Check Questions]], Security skill check Q4) |
| Vault key protection modes | 2 | HSM (key material never leaves the HSM; all crypto ops happen inside it) vs. Software (exportable, but still encrypted at rest by an HSM-rooted key — "Software" is HSM-*rooted*, not HSM-*free*). Console defaults to HSM. |
| Vault types | 2 | Shared/Default vault (multi-tenant HSM partition), Virtual Private Vault (dedicated HSM partition, distinct pricing, higher key-version ceiling) |
| Dedicated KMS's core differentiator | 1 fact | Single-tenant HSM partition with full control — **not** shared (a confirmed skill-check miss, see [[MyLearn Skill Check Questions]], Security skill check Q5) |
| Autonomous DB Serverless network access tiers | 3 | Secure access from everywhere, Private endpoint access only, Secure access from allowed IPs and VCNs only — **not** "Access only from OCI peered VCNs" (fabricated distractor, seen on skill check) |
| Autonomous DB Serverless network access auth enforcement | varies by tier | Public/internet-accessible tier enforces mTLS (mandatory, both sides authenticate via cert); the other two tiers support both mTLS and TLS, with mTLS as the relaxable default |
| Fault domains per Availability Domain | 3 | Fixed — every AD has exactly 3 fault domains, regardless of region or how many ADs that region has. This is why 3-way spread patterns recur across OCI HA designs (instance pools, LB backend sets). |
| Compute capacity types | 4 | On-demand (default), Preemptible (reclaimable, cheap, analogous to AWS Spot but verify OCI's own notice period), Capacity Reservation (guarantees availability, billed whether or not you launch into it), Dedicated VM Host (whole physical host, no other tenant's VMs) |
| Compute image types | 3 | Platform image (Oracle-maintained), Custom image (captured from your own instance, you own patching), BYOI (imported from outside OCI as-is) |
| Instance maintenance recovery actions | 2 | Live migration (default for VM shapes where supported, no reboot), Reboot migration (used when live migration isn't possible for that shape/scenario) — don't assume live migration is universal across all shapes |
| Instance connection methods | 3 | SSH (Linux, default path), Instance Console Connection (serial-console-style, network-stack-independent — the fallback when SSH itself is unreachable), RDP (Windows) |
| Instance variant flavors (security/performance add-ons, not alternative shapes) | 3 | Burstable (baseline OCPU + temporary burst), Shielded (virtual TPM + Secure Boot, boot-chain integrity), Confidential Computing (encrypts memory *in use*, not just at rest/in transit — closes the gap other encryption doesn't cover) |
| Storage-with-Compute categories | 4 | Boot Volume (persistent boot disk, back up separately), Block Volume (durable block storage, single/multi-attach), File Storage (managed shared NFS), Object Storage (object/data-lake/backup pattern, not a mounted block-volume replacement) |
| OCI DevOps Build Pipeline (CI) stages, in order | 4 | Code Repository (commit-triggered) → Run Build → Test Artifacts → Deliver Artifacts (writes to Container Registry or Artifact Registry) |
| OCI DevOps Deployment Pipeline (CD) stages, in order | 4 | Deploy to staging → Run Integration Tests → Approval (a named, discrete pipeline stage — not just a general best practice) → Deploy to PROD |
| OCI DevOps deploy targets ("OCI platforms" grouping) | 3 | Compute hosts (VM and Bare Metal), Container Engine for Kubernetes (OKE), Functions |
| OCI Artifact Repository types | 2 | Container Registry (container images, Helm charts), Artifact Registry (generic packages) |
| Named deployment/release strategies | 3 | Rolling (health checks + explicit rollback criterion required), Canary (traffic routing determines who gets it — deployment alone doesn't), Blue-green (requires duplicate capacity + controlled traffic switch) |
| Observability service split (don't collapse into one) | 4 | Monitoring (metrics/alarms), Logging (service/application logs), APM (traces/performance — not a substitute for logs/alarms/audit), Logging Analytics (broader log analysis) — Audit is a distinct 5th, control-plane-change-only service, not application telemetry |
| File Storage resources for one filesystem | 2 | File System (the actual NFS data) + Mount Target (the network-attached endpoint clients connect through) — two separate resources; NSGs/security lists apply to the **Mount Target's** VNIC, not the File System itself |
| File Storage access-control layers (stacked, both apply) | 2 | NSG/security-list gate on the Mount Target's VNIC (network-level) + NFS Export Options (filesystem-level: source CIDR, read/write vs. read-only, root-squash) |
| File Storage snapshot vs. clone | 2 | Snapshot = point-in-time read-only capture, browsable via a hidden `.snapshot` directory inside the mount; Clone = new independent writable File System created from a snapshot |
| Block Volume backup vs. clone | 2 | Backup = point-in-time storage-side copy you restore *from* (new volume on restore) — recoverability over time; Clone = immediate full-copy new volume from an existing volume or backup — point-in-time duplication/fast-provisioning |
| Block Volume performance tiers | 2 named + 1 auto mode | Balanced, Higher Performance (both selectable, cost-vs-IOPS tradeoff), plus Dynamic Performance (auto-scales based on utilization instead of provisioning for peak) |
| Block Volume attachment types | 2 | Paravirtualized (simpler, no in-guest iSCSI config, default for most shapes, lower volume-count limit, not on every shape) vs. iSCSI (requires guest-OS iSCSI initiator commands, higher volume-count ceiling, works on shapes paravirtualized doesn't — notably bare metal) |
| Block Volume access types | 2 | Single-attach (default, one instance) vs. Multi-attach (same volume, multiple instances concurrently — OCI does NOT provide clustering/concurrency control on top; the workload itself, e.g. OCFS2, must coordinate writes or data corrupts) — distinct from a Volume Group, which coordinates backup/clone timing across *separate* volumes on one instance (inverse relationship) |
| Reserved IPs at the ends of a subnet CIDR | 2 | OCI reserves the **first two and last** IP of every subnet — NOT AWS's five-address reservation rule, don't carry that number over |
| Minimum legal subnet size and its usable-IP trap | 1 size / 1 usable IP | `/30` is the minimum OCI allows, but it yields only **1 usable IP** (4 total minus 3 reserved) — legal but a real trap for anything meant to scale (instance pools, OKE workers, Functions concurrency) |
| Public IP types | 4 | Ephemeral (auto-assigned, does NOT survive a stop/start cycle — common exam trap), Reserved (standalone resource, persists through instance termination/recreation), BYOIP (import your own owned range), Public IP Pools (provision from a pool rather than one at a time) |
| VCN peering/transit mechanisms | 3 | Local Peering (LPG, same-region VCN-to-VCN), Remote Peering (RPC, cross-region DRG-to-DRG), DRG transit (hub-and-spoke/many-VCN/hybrid — attachments do NOT communicate by default, route tables/distributions must be explicitly designed) |
| DRG attachment types | 4 | VCNs, Remote Peering Connections, Site-to-Site VPN IPSec tunnels, FastConnect virtual circuits — all attach to the same DRG, each via its own DRG route table |
| Hybrid connectivity options | 2 | Site-to-Site VPN (encrypted IPSec over internet, good FastConnect backup), FastConnect (private dedicated connectivity — NOT automatically encrypted; add an IPSec overlay if encryption-in-transit is required) |
| Load-balancing service selection (by traffic layer) | 4 | Load Balancer (L7, HTTP/HTTPS/TLS termination/host-path routing), Network Load Balancer (L3/4, high-performance TCP/UDP/IP, source-IP preservation), DNS Traffic Management + Health Checks (DNS-level steering, not instant — bounded by TTL), WAF (L7 attack protection, not a substitute for any of the above) |
| DNS Traffic Management steering policy types (named, purpose-specific) | 2 | Failover (active-passive, health-check-driven), Load Balancer steering (weighted distribution/canary designs) |
| NSG vs. Security List rule statefulness | 2 modes, both controls support both | Stateful (return traffic auto-allowed) vs. Stateless (explicit ingress AND egress rules required both directions) — Oracle recommends stateless specifically for high-volume Load Balancer subnets |
| Network Path Analyzer endpoint types (for `oci vn-monitoring path-analysis`) | 6+ named | SUBNET (needs subnetId **and** an address within that CIDR, not just the OCID), VNIC, COMPUTE_INSTANCE, IP_ADDRESS, LOAD_BALANCER, and others — a real, confirmed IAM gotcha: Path Analyzer needs its own explicit policy grant separate from generic `virtual-network-family` permissions, even when the identity has broad access to every other networking resource type |
| FastConnect virtual circuit types | 2 | Public virtual circuit (reaches OCI public services like Object Storage, no internet transit), Private virtual circuit (reaches your VCN directly, as if extending on-prem network) — choice depends on what you're connecting to, not just "more private is always better" |
| FastConnect provisioning models | 2 | Dedicated (direct physical cross-connect Oracle provisions for you — higher effort, no intermediary), Partner (through a FastConnect partner's existing network — faster to provision, no physical link to manage yourself) |
| Oracle Database@Azure network path (fabricated-distractor trap) | 1 fact | The Azure-to-OCI backend link (Object Storage backups, Vault key management) runs over an **OCI-managed, carrier-grade private network Oracle provisions and operates for you** — NOT a customer-built Site-to-Site VPN or FastConnect circuit. A scenario answer choice suggesting "set up a VPN between Azure and OCI" to reach Database@Azure is a distractor — that connectivity is already part of the managed product. |
| Organization Management parent tenancy's role | 3 | Manage member tenancies, centrally report on cost usage across all of them, enforce governance across the organization as a whole |
| Organization Management child tenancy's role | 3 | Isolated environment by default (own separate IAM/identity root, not a sub-compartment), shares parent's UCM subscription (only billing changes), scalable up to **50 child tenancies by default** |
| Organization Management enforceable governance dimensions | 3, exactly | Service quotas, allowed regions, tagging — a closed set, not a generic "policy" mechanism; distinct from ordinary IAM policy (governs access, not quota/region/tag constraints) |
| Organization Management benefits of sharing a subscription | 4 | Data Isolation, Ease of Consolidated Billing, Separate Governance and Security, Central Cost Management — Data Isolation and Separate Governance/Security are two distinct benefits, don't collapse them into one |
| Organization Management Console tools | 5 | Manage tenancies, Map subscriptions, Manage invitations, Create governance rules, plus the Overview/Tenancies/Invitations/Subscription Mapping/Governance Rules left-nav mirroring the same 5 areas |
| Ways to add a child tenancy | 2 | Invite an existing, separately-owned tenancy to join (accept/decline via Manage Invitations), or Create a brand-new tenancy directly inside the organization |
| Governance rule attach scope | 2 | "Attach to specific tenancies" (named only) vs. "Attach to entire organization" (self-extends to future/not-yet-created child tenancies automatically — a real forward-looking design lever) |
| Child tenancy name constraints (a real, exact-format fact) | 1 rule | Lowercase letters and numbers only, no spaces, max 25 characters, must start with a letter |
| What's reversible vs. permanent when creating a child tenancy | 1 permanent + 2 reversible | **Home region is permanent** (cannot be changed after provisioning — same one-time commitment as a standalone tenancy); subscription mapping IS changeable after creation (re-map to a different subscription later); governance-rule attachment IS optional and reversible (attach/detach/opt-out anytime after creation) — don't conflate the one irreversible choice with the two reversible ones |

| OKE node pool types | 3, not 2 | Managed nodes (standard OCI Compute in an OKE-native NodePool — Oracle orchestrates the pool, but Kubelet + container runtime on each node are yours to understand/patch), Virtual nodes (serverless, Oracle-managed end to end — Basic tier does NOT support these at all), Self-managed nodes (bring your own Instance Pool, register it yourself — OKE just accepts the join) |
| OKE cluster tiers | 2 | Basic (SLO only, no financial remedy if missed; no Virtual Nodes, no fine-grained add-on config, no workload identity, lower worker-node ceiling) vs. Enhanced (paid, financially-backed SLA consideration, strict superset of Basic features) — **tier change is upgrade-only, never downgrade**, a one-way door |
| OKE cluster-creation tier defaults by tool (easy to get backwards) | 2 opposite defaults | Console defaults to **Enhanced** (opt into Basic explicitly); CLI/API defaults to **Basic** (opt into Enhanced explicitly) |
| Managed Node image categories | 3 | Platform image (bare Oracle-maintained OS), OKE image (platform image + pre-baked kubelet/runtime/OKE config — faster node provisioning), Custom image (your own customization on top of either) — **Console cannot provision a managed node pool from a custom image at all**, CLI/API only, a real capability gap not just a default difference |
| OKE control-plane components (fully Oracle-managed regardless of tier) | 5 | `kube-apiserver`, `kube-scheduler`, `kube-controller-manager`, `cloud-controller-manager`, `etcd` — you never provision, patch, or scale any of these yourself |

*Source detail for each row lives in the corresponding numbered Note file ([[6. Databases — OCI Database, NoSQL, Caching, DR]] for DB rows, [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]] for IAM/Vault/Network Firewall rows, [[3. Compute — OCI Compute, Instance Pools, Load Balancers, Volumes]] for Compute rows, [[1. DevOps — OCI DevOps, CI-CD, Observability]] for DevOps/Observability rows, [[4. Storage — OCI Object, Archive, File, Block Storage]] for Storage rows, [[9. Networking — OCI VCN, DRG, Gateways, Load Balancers]] for Networking rows, [[7. Multicloud and Hybrid — Oracle Database@Azure, FastConnect, DRG]] for Multicloud/Hybrid rows, [[8. Management and Governance — OCI Resource Manager, OS Management Hub, Observability]] for Governance/Organization Management rows, [[12. Containers — OCI OKE, Container Instances, OCIR]] for Containers/OKE rows). Add rows here as new finite lists turn up in other domains (Migration, Serverless, etc.) — this table is meant to keep growing across the whole exam, not stay Databases-only.*

## 4a. Swapped-noun and "auto" traps seen in practice exam attempt 2

The wrong option usually reads correctly except for **one swapped service or
field name**, or an invented **"auto"** step. Before choosing, ask *where does
this actually run / what does this field actually do?*

| Trap option | Swapped for | Question |
|---|---|---|
| "…deployed only to **OKE**" | OCI Functions runs in a Functions application | Events + Functions demo |
| **Resolution** | **Interval** is the aggregation window | Monitoring query |
| Block volume **replication across ADs** | **Continuous redo** to Recovery Service | Near-zero data loss |
| Kubernetes **docker-registry secret** | **Auth token** for `docker login` | OCIR push/pull |
| "Vault **auto-encrypt… auto-decrypted** config variable" | Encrypt with Vault, **decrypt in function code** | Functions DB password (**missed in both attempts**) |
| Point-in-time **restore** of production | **Clone** from a pre-corruption backup | Keep corrupted state for investigation |

## 5. Study approach adjustments vs. your AWS process
- Question banks (WhizLabs-equivalent for OCI) are useful for the MCQ portion only — don't mistake a high practice-test score for lab readiness.
- Build everything in Week 1-3 of the plan in an actual tenancy at least once without following a tutorial verbatim, close to exam conditions, before your final week.
- No personal weak-area baseline exists yet for this exam (unlike your AWS notes going back to 2019/2023) — this file will need real updates after your first practice assessment and again after the actual exam, the way your AWS tips file accumulated corrections over multiple passes.

---

## Open items to fill in as you go
- [x] Exact current domain weightings — confirmed directly from the official prep workshop video (see new section below).
- [ ] Whether your OCI employee status gives voucher/discount access to the $245 fee or paid Professional course content
- [ ] Post-practice-assessment: which domains are actually your weak spots (can't front-load this one, unlike AWS)

---

## 6. Official exam domain weights (confirmed verbatim from Oracle's own prep workshop)

Source: MyLearn course "Prepare for Oracle Cloud Infrastructure Architect Professional Certification" ([course 163275](https://mylearn.oracle.com/ou/course/prepare-for-oracle-cloud-infrastructure-architect-professional-certification/163275/273240)), Parts 1 and 2 — an Oracle University-produced exam-prep workshop, not third-party speculation. Stated explicitly by the instructor as the exam's own objective weighting.

| Domain | Weight |
| --- | --- |
| Architect High Availability and Disaster Recovery Solutions | 15% |
| Architect Cloud-Native Solutions | 20% |
| Architect Security Solutions | 25% |
| Architecting, Implementing, and Operating Databases in OCI | 20% |
| Implementing Observability Solutions | 20% |

**Security is the single largest domain at 25%** — heavier than any other individual domain, including Databases. Worth weighting study time accordingly rather than assuming an even split across the five domains.

**Per-domain concepts named explicitly in the workshop** (a real, if partial, syllabus signal — not the full blueprint, but confirms what Oracle itself chose to spotlight):
- **HA/DR**: designing scalable/resilient/HA OCI architectures; **Full Stack Disaster Recovery** service specifically named.
- **Cloud-Native**: microservice architecture, containerization, DevOps practices with **OKE, Container Instances, OCI DevOps**; container image management/orchestration via **OCIR + OKE**; infrastructure-as-code via **OCI Functions and Resource Manager**.
- **Security**: designing/implementing secure OCI architectures; **OCI Bastion, Zero Trust Packet Routing, OCI Network Firewall**; app/data security via **WAF, OCI Certificates, Key Management Service**; governance/tenancy management via **OCI Organizations Management**.
- **Databases**: scalable/HA database design via **Base Database Service and Autonomous Database**; automated backup/recovery/business continuity via **Autonomous Recovery Service**; globally distributed low-latency design via **Globally Distributed Autonomous Database**; app scalability/responsiveness via **OCI Cache**.
- **Observability**: monitoring, logging, alerting, **Connector Hub**, **OCI Search**.

## 7. Worked sample questions from the official prep workshop — the exact reasoning pattern to copy

Oracle's own instructor explicitly frames these as **not real exam questions**, just pattern-matched emulations meant to teach the keyword/elimination approach documented in Section 1 above. Five questions, one per domain — captured with the instructor's own reasoning chain since *how* he eliminates options is the actual teaching content, not just the final answer.

1. **HA/DR** — Scenario: natural disaster hits the primary region, need to switch operations to a DR region with **minimal downtime**. Which Full Stack DR feature achieves this?
   Options: (A) manual reconfiguration of DNS/resource settings, (B) manually creating snapshots of individual resources, (C) writing custom DR scripts, (D) automated failover of the complete application stack.
   **Answer: D.** Reasoning: the question's keyword is "minimal downtime" — options A–C all describe *manual* effort, which contradicts minimal downtime. FSR's actual value proposition is automating failover across the entire stack, not partial/manual mechanisms.

2. **Cloud-Native** — Scenario: dev team needs to push/pull container images via Docker CLI against a **private OCI Container Registry (OCIR)**. Which authentication method?
   Options: (A) master encryption key in OCI Vault, (B) SSH key pair, (C) generate and use an auth token, (D) JSON Web Token.
   **Answer: C.** Reasoning: OCIR authenticates Docker CLI access specifically via an **auth token** generated from the user's OCI profile, used alongside the username at `docker login` — a token-based method that avoids exposing the account password.

3. **Security** — Scenario: compute instances in a **private subnet** must have no direct internet access, with tightly controlled admin access. Which statement correctly explains **OCI Bastion's** purpose here?
   Options: (A) provides a public endpoint directly on the compute instance, (B) offers a secure controlled public entry point for accessing private-subnet resources, (C) functions as a firewall blocking all external traffic, (D) acts as an additional credential-validation auth service.
   **Answer: B.** Reasoning: eliminate A (Bastion doesn't put a public endpoint *on* the instance — that defeats the "no direct internet access" requirement), C (Bastion isn't a firewall), and D (it isn't a credential-validation layer). Bastion's actual mechanism is a managed, controlled entry point (SSH port forwarding/session-based access) to reach private-subnet instances without giving them public IPs.

4. **Databases** — Scenario: evaluating **Oracle Database Autonomous Recovery Service** for DR/backup strategy. Which underlying technology is ARS built on?
   Options: (A) Oracle Data Guard, (B) Oracle RMAN, (C) Oracle Zero Data Loss Recovery Appliance, (D) Oracle GoldenGate.
   **Answer: C.** A direct fact, not an elimination exercise: ARS is built on **Zero Data Loss Recovery Appliance** technology, delivering efficient backups, rapid recovery, and near-zero data loss for Oracle databases. Cross-reference: this is the **on-premises/general Oracle Database** service; don't confuse with **Zero Data Loss Autonomous Recovery Service (ZRCV)**, the Autonomous-Database-specific sub-second-RPO tier documented in [[6. Databases — OCI Database, NoSQL, Caching, DR]].

5. **Observability** — Scenario: using **OCI Connector Hub** to move logs from OCI Logging to Object Storage, but want to transfer **only error-level logs** to reduce storage. Which Connector Hub feature?
   Options: (A) agent configuration, (B) log filter task, (C) tags, (D) IAM policies.
   **Answer: B.** Reasoning: a **log filter task** is the Connector Hub mechanism that filters/processes logs *before* they reach the target service — the only one of the four options that actually operates on log content/severity rather than agent setup, resource labeling, or access control.
