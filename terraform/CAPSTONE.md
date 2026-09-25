# MyMagnet Capstone

One real application that ties the separate labs in [LABS.md](LABS.md) together.
`lab-mymagnet-stack` is the base: it's the only lab running a real app
([rockkw/MyMagnet](https://github.com/rockkw/MyMagnet)), and it already uses a
load balancer, NSGs, a NAT-routed private subnet, Vault, OCI Certificates, Object
Storage and an instance-principal dynamic group.

The capstone adds three AI pieces, chosen because each one also covers a
1Z0-997-26 exam domain (the exam itself has no AI domain):

1. **Autonomous AI Database (26ai; 23ai also offered).** Replaces the per-node SQLite library, with AI
   Vector Search on embeddings created *inside* the database by an ONNX model.
2. **Event-driven enrichment.** Object Storage → Events → Function → model →
   database, adapted from `lab-document-understanding-stack`.
3. **Self-hosted model on OKE, CPU only.** llama.cpp's server with a small
   quantized model on one Ampere A1 node (`lab-oke-cpu-inference-pool-stack`),
   behind an internal LB. **No GPUs** (decided 2026-09-25). It takes the place of
   the hosted OCI Generative AI service, which the capstone deliberately doesn't use.

## Architecture

```
Internet ──► LB (reserved IP, HTTP + HTTPS via OCI Certificates)       public subnet
               │
               ├─► mymagnet-instance-1 ┐                               private subnet (NAT)
               └─► mymagnet-instance-2 ┘── read/write ──► Autonomous AI DB 26ai
                        │                                   (vector search, ONNX embeddings)
                        └─ results ──► Object Storage ──► Event ──► Function
                                                                     │
                                          internal LB ◄──────────────┘
                                              │
                              OKE A1 CPU node pool (llama.cpp server)
```

## Phases

| # | Phase | Exam domains | Reuses | Status |
|---|---|---|---|---|
| 1 | Fix MyMagnet blockers (HTTPS certificate chain, app reachability) | Security | `lab-mymagnet-stack` | Done 2026-09-24: HTTP-only via LB, HTTPS removed, fault domains split, backup dynamic group fixed |
| 2 | SQLite → Autonomous AI Database (26ai) + AI Vector Search | Databases | `lab-basedb-stack` (network pattern), `lab-mymagnet-stack` (Vault, dynamic group) | `lab-capstone-adb-stack` written: validate clean, plan 10 to add. `sql/` scripts and MyMagnet app patch drafted. Apply, SQL and app rollout deferred (see Deferred) |
| 3 | Enrichment pipeline, with a placeholder tag at first so it's testable without a GPU | Cloud-Native, Security | `lab-document-understanding-stack`, `lab-func-stack` | `lab-capstone-enrich-stack` written: validate clean, plan 9 to add, 9 unit tests pass. Image build/push and apply deferred (see Deferred). ADB write is a marked hook in func.py |
| 4 | Self-hosted model on OKE, **CPU only, no GPU**: llama.cpp server + Qwen2.5-1.5B-Instruct Q4_K_M on a 4 OCPU / 12 GB A1 node, behind an internal LB; point the Function at it | Cloud-Native | `lab-oke-stack` (`lab-oke-gpu-stack` is not used) | **Live 2026-09-25.** `lab-oke-cpu-inference-pool-stack` applied (1 × A1, 4 OCPU / 12 GB, label `workload=llm`); llama.cpp deployed in namespace `vllm`; internal LB `10.0.2.231`. Smoke test through the LB: `/health` 200, no key 401, chat reply at ~24.5 tokens/s. A GPU pool was briefly created, then destroyed (~10 min) after the no-GPU decision. Also fixed a pre-existing OKE bug: workers NSG lacked ingress 10250 from the control plane, so `kubectl logs/exec` timed out |
| 5 | Observability (UMA logs, custom metrics, alarms → Notifications) and HA/DR (fault domains, cross-region bucket replication, DNS failover) | Observability, HA/DR | Lab 2 design | Applied 2026-09-25: log group + 3 custom logs + agent configs, 3 alarms (all OK), topic + email subscription, log-archive bucket with lifecycle rule, 4 IAM resources. Connector Hub waits on the agent install (see Deferred); HA/DR designed below |

### Phase 1: HTTPS removed, app served over HTTP

**Decision (2026-09-24):** HTTPS was dropped for now. The CA, leaf certificate,
443 listener and 443 NSG rule are removed from `lab-mymagnet-stack/main.tf`. The
app is already reachable over HTTP through the LB. The Vault and key stay for
later phases.

**Likely root cause, kept for when HTTPS comes back:** the CA calls Vault as its
*own resource principal* when it signs with its key. The two policies tried
earlier granted access to `service certificates`, which is the wrong principal.
The fix to try:

- A dynamic group with the rule
  `ALL {resource.type = 'certificateauthority', resource.compartment.id = '<compartment>'}`
- A policy granting that group `use keys` and `manage objects` in the compartment
- The CA resource `depends_on` the policy

This matches the `OCI-SM-CA-DG` dynamic group recorded in Note 5 and the MyLearn
skill-check answer ("the CA makes API calls to Vault").

Two other fixes, found while re-planning on 2026-09-24:

- **Stale instance dynamic group.** `mymagnet-instance-dyn-grp` still matched the
  two instances that were *replaced* in the subnet fix, so neither live instance
  can authenticate to the backup bucket. The next apply corrects the rule.
- **Boot-volume wipe risk.** The Ubuntu image data source now returns a newer
  build, and a changed `source_id` replaces the boot volume in place. Added
  `lifecycle { ignore_changes = [source_details[0].source_id] }` to both
  instances.

Inputs are now in `lab-mymagnet-stack/terraform.tfvars` (gitignored), recovered
from state, so `terraform plan` runs with no `-var` flags.

**Applied 2026-09-24** (0 added, 2 changed, 1 destroyed): 443 NSG rule removed,
instance 1 moved to FAULT-DOMAIN-1 (instance 2 stays in FD-2), instance dynamic
group now matches the live instances. Verified: both instances RUNNING in
separate fault domains, both LB backends `OK` (briefly `WARNING` while instance
1 restarted), `curl http://137.131.32.68/` returns 200 with the Magnet Library
page.

### Phase 2 notes: Autonomous AI Database (26ai)

Built as `lab-capstone-adb-stack`; the full write-up is in LABS.md.

- **Version:** `db_version = "26ai"`. On 2026-09-24,
  `oci db autonomous-db-version list` in Phoenix listed 19c, 23ai and 26ai,
  and marked 26ai as the paid default.
- **Network:** a private endpoint in the instance subnet `10.0.2.0/24`. Its
  NSG allows TCP 1522 from that subnet only. mTLS is not required, so
  python-oracledb Thin mode connects with user, password and DSN, and no wallet.
- **Size and cost:** 2 ECPUs (the minimum), 20 GB, CPU and storage auto-scaling
  off. **Always Free was rejected.** It's home-region only (Ashburn), it can't use
  a private endpoint or sit in a VCN, and it stops after 7 idle days. Stop the
  paid database between study sessions.
- **Passwords:** `random_password` → Vault secrets, encrypted with a new AES
  key (`mymagnet-secrets-key`). The existing mymagnet key is RSA and can't
  encrypt secrets. The ADB takes ADMIN via `secret_id`. The app user `MAGNET`
  has its own secret, and a home-region policy lets the instances read it.
- **Embeddings:** `DBMS_VECTOR.LOAD_ONNX_MODEL_CLOUD` loads the unzipped
  `all_MiniLM_L12_v2.onnx` from a read-only PAR (`credential => NULL`).
  `title_vec VECTOR(384, FLOAT32)` is filled by `VECTOR_EMBEDDING()` on insert
  and by a one-time backfill. HNSW index, cosine distance.
- **App:** `app-patch/mymagnet-adb.patch` moves the app to python-oracledb with
  Oracle SQL, adds `GET /api/similar?q=`, and adds `migrate_sqlite_to_adb.py`,
  which merges both nodes' SQLite files. Once the app is on ADB, run the
  scraper timer on one node only; sticky sessions become unnecessary.
- **Optional Select AI:** `sql/select_ai_profile.sql` implements the steps
  below against the Phase 4 LB (placeholder host).
- **Select AI, answered 2026-09-24:** `DBMS_CLOUD_AI` profiles accept a
  `provider_endpoint` for any OpenAI-compatible server, vLLM included, so Select
  AI can use the Phase 4 model. With a private-endpoint database: the vLLM LB
  must be reachable from the database's VCN; set
  `ROUTE_OUTBOUND_CONNECTIONS = 'PRIVATE_ENDPOINT'`; and add a network ACL with
  `private_target => TRUE`
  ([Call Web Services](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/call-web-services.html)).
  **HTTPS is needed (checked 2026-09-25):** ADB's UTL_HTTP notes say "HTTP
  connections are disallowed for both public endpoints and private endpoints"
  ([PL/SQL package notes](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/autonomous-plsql-packages.html)).
  The Select AI pages don't restate it, but every `provider_endpoint` example is
  HTTPS. So the Phase 4 LB needs a certificate, which brings back the Phase 1 CA
  problem, and a private-CA certificate also needs a customer-managed wallet in
  the database. The script also needs an ADB NSG egress rule to the LB.
- **Phase 2 checks against Oracle docs (2026-09-25).** Each item was open before today:

  | Item | Verdict | Source |
  |---|---|---|
  | `.onnx` name in Oracle's zip | True: `all_MiniLM_L12_v2.onnx` (read from the zip's directory via an HTTP range request; the download URL in `sql/README.md` works, 122.5 MB) | [model page](https://docs.oracle.com/pls/topic/lookup?ctx=en/database/oracle/oracle-database/26/vecse&id=oml_ai_models_object_storage), [SQL Quick Start](https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/sql-quick-start-using-vector-embedding-model-uploaded-database.html) |
  | `DB_DEVELOPER_ROLE` includes `CREATE MINING MODEL` | True; the explicit grant in `sql/01` is redundant but harmless | [Security Guide 26ai](https://docs.oracle.com/en/database/oracle/oracle-database/26/dbseg/considerations-using-application-based-security.html) |
  | DML on an HNSW-indexed table | Allowed. Only RU 23.4 and 23.5 blocked it. Post-index rows go to a journal that queries scan exactly, so searches slow as DML builds up until the graph refreshes | [New Features: vector indexes](https://docs.oracle.com/en/database/oracle/oracle-database/26/nfcoa/vector-indexes.html), [HNSW transaction support](https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/hnsw-index-architecture-transaction-support-and-persistence.html) |
  | `VECTOR_EMBEDDING()` inside `MERGE` | Still unverified. The docs don't forbid it (it's allowed "as an operand for SQL operations accepting a VECTOR type"), but no Oracle example shows it. The backfill fallback stays | [VECTOR_EMBEDDING](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqlrf/vector_embedding.html) |
  | Bind in `FETCH APPROX FIRST :n ROWS ONLY` | True: `rowcount` "must be a number or an expression that evaluates to a numeric value". `EXACT` also exists, and `APPROXIMATE` is the default | [SELECT](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqlrf/SELECT.html) |
  | `START WITH LIMIT VALUE` | True for `ALTER TABLE … MODIFY`, which is the only place it's allowed and the only place the migration uses it. No ADB restriction was found | [CREATE TABLE](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqlrf/CREATE-TABLE.html) |
  | 20 GB minimum storage (ECPU, Transaction Processing) | True: "The minimum database storage size is 20 GB". The minimum is 2 ECPUs. Backups bill separately | [Billing summary](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/autonomous-database-billing-overview.html) |
  | Select AI over plain HTTP | False: HTTPS is needed (see above) | [PL/SQL package notes](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/autonomous-plsql-packages.html) |
  | Profile needs `"provider"` with `provider_endpoint` | False: without `provider`, "Select AI treats the endpoint as OpenAI-compatible" | [DBMS_CLOUD_AI](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/dbms-cloud-ai-package.html) |

  `sql/01`, `04`, `05`, `select_ai_profile.sql` (now `https://`), `sql/README.md`
  and `app-patch/README.md` were updated to match. No Terraform change was needed.
- **Naming:** Oracle's current docs call the service "Autonomous AI Database
  26ai" ([May 2026 release note](https://docs.oracle.com/en-us/iaas/releasenotes/autonomous-database-serverless/2026-05-outbound-conn-options.htm)),
  and 26ai is now the paid default (checked above). The vector features are the same.

### Phase 4 cost control

**No GPUs.** The capstone runs the model on CPU only (decided 2026-09-25).
`lab-oke-gpu-stack` stays in the repo as a separate lab, but the capstone doesn't
use it.

The model node is one `VM.Standard.A1.Flex` with 4 OCPUs and 12 GB
(`lab-oke-cpu-inference-pool-stack`). A1 list price is $0.01 per OCPU-hour
(B93297) plus $0.0015 per GB-hour (B93298), from the same price API as the
[Cost](#cost) table. That's $0.04 + $0.018 = **$0.058/hour, $42.34/month** (730 h).
The tenancy's Always Free A1 allowance (4 OCPUs / 24 GB in total) is already used
by the two MyMagnet instances and the two `lab-node-pool` nodes, so this node is
billed from the first hour. Destroy the pool between sessions; the PVC with the
model can stay.

Why 4 / 12 rather than 4 / 24: llama.cpp's speed scales with cores (one A1 OCPU
is one core, so 4 threads), while Qwen2.5-1.5B Q4_K_M needs only about 2.2 GB
resident (measured locally with the same image and flags). 12 GB still leaves room
to try a 7B Q4 model (~4.7 GB). Going to 24 GB would add $0.018/h ($13/month) for
memory the model can't use. A1 availability in PHX-AD-1 on 2026-09-25: 13,877
cores and 92,526 GB available (`oci limits resource-availability get`).

### Phase 4 notes: llama.cpp on OKE (CPU)

Stack: [`lab-capstone-vllm-stack`](lab-capstone-vllm-stack/) (the name is left over
from the GPU design), fully documented in
[LABS.md](LABS.md#lab-capstone-vllm-stack) with the bring-up, smoke-test and
tear-down runbook. The node comes from
[`lab-oke-cpu-inference-pool-stack`](LABS.md#lab-oke-cpu-inference-pool-stack).

- **Same VCN, same subnet.** `lab-oke-cluster` is in us-phoenix-1, in `lab-vcn`,
  which is MyMagnet's VCN. Its workers are in `10.0.2.0/24` next to the MyMagnet
  instances. No peering or move is needed.
- **Server:** llama.cpp's `llama-server`, image
  `ghcr.io/ggml-org/llama.cpp:server-b11176` (a multi-arch index with an arm64
  build, checked against the ghcr.io registry API). It serves the OpenAI-compatible
  `/v1/chat/completions` and `/v1/models`, so the Function code doesn't change.
- **Model:** `qwen2.5-1.5b-instruct-q4_k_m.gguf` (1.12 GB) from Qwen's official
  `Qwen/Qwen2.5-1.5B-Instruct-GGUF` repo, pinned to a commit and checked by sha256
  in an init container that downloads it once into the PVC. Apache-2.0, not gated.
  Served as `qwen2.5-1.5b-instruct` (`--alias`), 4 threads, 4096-token context.
  A 1.5B model gives rougher tags and summaries than the 7B planned for the GPU,
  which is fine for the pipeline.
- **Endpoint:** the same internal flexible LB at `http://<10.0.2.x>/v1/...`,
  reachable only from `10.0.2.0/24` (enforced by an NSG). Clients authenticate
  with a bearer token (`LLAMA_API_KEY` from the `vllm-api-key` Secret), because
  every OKE pod also gets an IP in that subnet. `/health` is public for the probes.
- **Scheduling:** the pool's nodes carry the label `workload=llm`, and the
  Deployment's `nodeSelector` uses it. No GPU requests; the pod requests 3 CPU and
  3 GiB (limit 6 GiB, no CPU limit).
- **Select AI: not over this LB as built.** Autonomous Database refuses
  plain-HTTP outbound calls on both public and private endpoints (see the Phase 2
  notes), so Select AI can't call `http://<LB_IP>`. It would need TLS on this LB,
  which is future work. The Phase 3 Function is unaffected and stays on HTTP.

### Phase 5: Observability (built) and HA/DR (design only)

**Observability** is `lab-capstone-observability-stack` (details in
[LABS.md](LABS.md)): a log group with UMA custom logs for the app and nginx,
alarms for unhealthy backends, backend 5xx and instance CPU sent to a
Notifications email topic, and an optional Connector Hub archive to a bucket
with a lifecycle policy. **Ampere catch, verified in Oracle's plugin docs:**
the Custom Logs Monitoring plugin isn't supported on A1 shapes. The stack
assumes the standalone aarch64 Ubuntu 24.04 agent is installed by hand. Test
that on one node first. If it fails, switch to an x86 shape or call `PutLogs`
from the app.

**HA/DR design** follows [Lab 2](../Lab%202%20-%20OCI%20Architect%20Pro%20Exam%20-%20HADR%20Design.md).
Primary is Phoenix and standby is Ashburn, which is also the home region.

| Piece | Design | RPO | RTO | Exam concept |
|---|---|---|---|---|
| Fault domains | **Both instances sit in PHX-AD-1 / FAULT-DOMAIN-2**, so one rack fault can take down both (checked in state on 2026-09-24). `lab-mymagnet-stack` now pins `mymagnet_1` to FD-1 and `mymagnet_2` to FD-2 (applied 2026-09-24). Oracle updates this in place: a running instance is stopped, moved and restarted. Keep the other node serving during the move. If the target FD has no A1 capacity, the instance stays stopped. | Per-node SQLite on the failed node, until Phase 2 moves data to ADB | ≈ health-check interval (LB drops the backend) | FDs = anti-affinity within one AD. Phoenix has 3 ADs, but moving ADs replaces the instance (new IP, empty SQLite) |
| Backup bucket | `oci_objectstorage_replication_policy` on `mymagnet-backups`, Phoenix → Ashburn. It needs the same `objectstorage-us-phoenix-1 manage object-family` service policy that this phase's stack adds. The target is read-only until the policy is deleted, which is the promotion step. | Async, typically minutes | Minutes (delete the policy, repoint the app) | Replication vs backup per tier |
| DNS failover | Traffic Management **FAILOVER** steering policy. Answer 1 is the Phoenix LB IP and answer 2 is an Ashburn LB. An HTTP health check on `/` with TTL around 30 s. **Blocked:** it needs a public DNS zone for a domain, and none is managed in OCI yet. | n/a | Health-check failures × interval + TTL | Layer 3 failover: automatic, bounded by TTL |
| Autonomous DB (Phase 2) | Autonomous Data Guard with a **local** standby (automatic failover) plus a **cross-region** standby in Ashburn. A private endpoint needs a VCN and subnet in Ashburn. | Local 0 s; cross-region ≤ 1 min (manual failover) | Local 2 min; cross-region < 10 min | Oracle ADB doc numbers. Cross-region has **no automatic failover**. Backup-based DR is the cheaper option with a higher RTO |
| Full Stack DR | Peered DR Protection Groups in Phoenix and Ashburn. Members are the ADB, both instances (or their volume groups) and the LB. | Driven by ADB/volume replication | Sum of plan groups | Warm DB + cold app tier (Lab 2) |

**Full Stack DR plan order (switchover):** (1) Precheck. (2) Built-in *Switchover
Autonomous Database*: the DB goes first so the app comes up against a writable
primary. (3) Launch or start the compute instances in Ashburn from replicated
volume groups. (4) Update the standby LB backend set. (5) User-defined step:
stop bucket replication and point `MAGNET_S3_BUCKET` at the Ashburn bucket.
(6) Traffic moves by itself once the Phoenix health check fails. A **Failover**
plan skips the orderly shutdown of Phoenix. It is triggered by a person, while
ADG's local failover is automatic. Run a Precheck every month and a DR Drill
every quarter. **Unverified:** whether Object Storage buckets can be DR
Protection Group members; the docs confirm compute, volume groups, LBs and
databases.

## Cost

List prices in USD with no region adjustment, pay-as-you-go. Monthly = 730 h.
Prices come from Oracle's cost-estimator price API
(`https://apexapps.oracle.com/pls/apex/cetools/api/v1/products/?currencyCode=USD`,
the data behind [oracle.com/cloud/price-list](https://www.oracle.com/cloud/price-list/);
feed `lastUpdated` 2026-09-23), fetched on **2026-09-25**. Part numbers are listed
so each price can be re-checked.

| Phase | Item (as configured) | Unit price | Hourly | Monthly |
|---|---|---|---|---|
| 2 | ADB Serverless, Transaction Processing, 2 ECPUs, `LICENSE_INCLUDED`, auto-scaling off | $0.336 / ECPU-h (B95702) | $0.672 | $490.56 |
| 2 | ADB storage, 20 GB (the minimum) | $0.1953 / GB-month (B95706) | $0.0054 | $3.91 |
| 2 | ADB backup storage (billed separately for ECPU; size unknown until it runs) | $0.0299 / GB-month (B95754) | — | ~$0.30 per 10 GB |
| **2** | **Running 24×7** | | **$0.68** | **≈ $494.47** + backups |
| **2** | **Stopped** (no ECPU billing while stopped; storage still bills) | | $0.005 | **≈ $3.91** + backups |
| 4 | `VM.Standard.A1.Flex` node, 4 OCPUs / 12 GB (CPU only; Always Free A1 already used) | $0.01 / OCPU-h (B93297) + $0.0015 / GB-h (B93298) | $0.058 | $42.34 |
| 4 | Boot volume 50 GB (OKE default), Balanced (10 VPU/GB) | $0.0255 / GB-month (B91961) + 10 × $0.0017 VPU (B91962) | $0.0029 | $2.13 |
| 4 | Model-cache PVC, 50 GB (`oci-bv` minimum, assumed Balanced) | same as above | $0.0029 | $2.13 |
| 4 | Internal flexible LB, 10 Mbps | $0.0113 / LB-h (B93030) + $0.0001 / Mbps-h (B93031) | $0.0123 | $8.98 |
| 4 | OKE control plane: `lab-oke-stack` is `BASIC_CLUSTER` | Basic = Free; Enhanced would be $0.10/cluster-h (B96545) | $0 | $0 |
| **4** | **Running 24×7** | | **≈ $0.076** | **≈ $55.58** |
| 3 | Functions, Events, Object Storage (plus the 738 MB OCIR image) at lab volume | Functions: first 400,000 GB-s and 2M invocations per month free (B90617, B90618). Events: free. Object Storage: first 10 GB and 50,000 requests per month free (B91628, B91627) | $0 | **$0** (within free tiers) |

Notes:

- **All three running 24×7 ≈ $0.76/h, ≈ $550/month.** The ADB is 90% of that.
  Phase 4 is CPU only (no GPU); a 4-hour session costs about $0.30. Destroy the
  inference pool and stop the ADB between sessions (the ADB then costs ≈ $3.91/month
  plus backups). The earlier GPU design (`VM.GPU.A10.1`, $2.00/GPU-h, B95909) would
  have been ≈ $1,477/month for Phase 4 alone.
- **LB free tier.** The first 744 LB-hours and 7,440 Mbps-hours each month are
  free (Always Free). MyMagnet's public LB (10 Mbps minimum) already uses that
  allowance, so the Phase 4 LB is priced as billable. The same applies to the
  200 GB Always Free block storage, which the MyMagnet boot volumes probably
  already use.
- Not included: outbound data transfer (none expected; all traffic stays in
  the VCN), the Vault key and secrets (not priced here), and
  any NVIDIA AI Enterprise add-on (not used).
- Sources: [OKE pricing (Basic Cluster: Free)](https://www.oracle.com/cloud/cloud-native/kubernetes-engine/pricing/);
  [Events: "Events Service is free"](https://www.oracle.com/cloud/events-service/);
  [ADB billing summary (20 GB min, backups billed separately)](https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/autonomous-database-billing-overview.html);
  [ADB features billing ("A stopped Autonomous AI Database instance has zero ECPU usage")](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-features-billing.html);
  [ADB compute models (backup SKU B95754)](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-compute-models.html).
  All checked on 2026-09-25.

## Deferred

Items blocked during autonomous work. Each needs a person to run or approve it.

| Item | Why it's deferred | How to finish |
|---|---|---|
| HTTPS on the LB | Removed by decision; the CA fix needs an IAM grant | Re-add the CA chain with the dynamic group above |
| Phase 4: Select AI → the Phase 4 model | Needs HTTPS: ADB disallows plain-HTTP outbound calls (checked 2026-09-25, Phase 2 notes). The private CA certificate is blocked on IAM | Add TLS at the LB (LABS.md, "HTTPS later"), load the CA into a customer-managed wallet in the ADB, then run `sql/select_ai_profile.sql` (`provider_endpoint` = `https://<LB_IP>`) |
| Confirm the alarm email subscription | OCI sent a confirmation link to <alarm email>; the subscription is `PENDING` until it's clicked | Click the link in the email, then `oci ons subscription list -c <compartment> --region us-phoenix-1` should show `ACTIVE` |
| Get logs flowing into the MyMagnet log group | Correction 2026-09-25: the Custom Logs Monitoring plugin **is RUNNING on both A1 instances** (`oci instance-agent plugin list`), so no manual install should be needed. The OCI side checks out: agent configs are `VALID`/`ACTIVE`, target the dynamic group that matches both live instances, and the `use log-content` policy exists. But no log entries arrived in the ~25 minutes after apply, even with traffic. Diagnosing on the instance needs Run Command or SSH, which auto mode blocks. Run Command policy (`use instance-agent-command-execution-family`) was added 2026-09-25 (commit `dad9e91`, applied, read back), but the first command, created minutes after the change, stayed `ACCEPTED` for 20+ minutes. The agent itself works: `oci_computeagent` CPU metrics arrive from both instances every 5 minutes. Likely the command was rejected before the policy propagated; create a **new** command | Run on an instance (Console → instance → Run Command, or Bastion SSH): `systemctl status unified-monitoring-agent`, `tail -50 /var/log/unified-monitoring-agent/unified-monitoring-agent.log`, `ls -la /var/log/nginx /opt/magnetlookup/data/logs`. Likely suspects: file permissions (nginx logs are `adm`-group only), or the app log path/glob not matching |
| Turn on the Connector Hub log archive | Connector Hub rejects a log source with no data ("No log sources found to be read"), and the custom logs stay empty until the agent above is installed | After logs appear in the log group: `cd terraform/lab-capstone-observability-stack && terraform plan -var enable_log_connector=true -out=obs.tfplan`, then apply the plan |
| Push the Phase 3 function image | Built locally on 2026-09-24 (`phx.ocir.io/idtlmgo3jgde/capstone/enrich:0.0.1`, linux/amd64, 738 MB; handler and `oci` SDK import OK inside the image). Pushing images is blocked in auto mode | `docker login phx.ocir.io -u 'idtlmgo3jgde/<username>'` (auth token as password), then `docker push phx.ocir.io/idtlmgo3jgde/capstone/enrich:0.0.1` |
| Apply `lab-capstone-enrich-stack` (9 resources: 2 buckets, NSG + rule, Functions app + function, Events rule, dynamic group, policy) | Auto mode blocks `terraform apply` and IAM changes; needs the image above first | `cd terraform/lab-capstone-enrich-stack && terraform plan && terraform apply`, then upload a test object to `mymagnet-results` and read `enriched/<name>.enrichment.json` from `mymagnet-enrichment` (LABS.md has the commands) |
| Point the Phase 3 function at the Phase 4 model | Needs Phase 4 running, the `vllm-api-key` value stored as a Vault secret, and an apply (config + one IAM statement) | `cd terraform/lab-capstone-enrich-stack && terraform apply -var llm_endpoint=http://<internal-lb-ip> -var llm_model=qwen2.5-1.5b-instruct -var llm_api_key_secret_ocid=<vault-secret-ocid>` |
| Apply `lab-capstone-adb-stack` (10 resources: ADB, NSG + rule, AES key, 2 secrets, bucket, 1 IAM policy, 2 random passwords) | Auto mode blocks `terraform apply` and IAM changes, and the ADB starts paid billing (2 ECPUs) | `cd terraform/lab-capstone-adb-stack && terraform plan && terraform apply`; stop the database between sessions with `oci db autonomous-database stop --autonomous-database-id "$(terraform output -raw autonomous_database_id)"` |
| Upload the ONNX model and create its PAR | Needs the bucket from the apply above; creating objects and PARs is a write | Follow `lab-capstone-adb-stack/sql/README.md`: `curl` + `unzip` Oracle's `all_MiniLM_L12_v2_augmented.zip`, `oci os object put -bn mymagnet-onnx-models --file all_MiniLM_L12_v2.onnx --name all_MiniLM_L12_v2.onnx --region us-phoenix-1`, `oci os preauth-request create -bn mymagnet-onnx-models --name onnx-load --access-type ObjectRead --object-name all_MiniLM_L12_v2.onnx --time-expires <+1 day> --region us-phoenix-1` |
| Run the Phase 2 SQL scripts | The ADB has only a private endpoint, so the scripts must run from inside the VCN (an instance or a Bastion session) against a live database | From a MyMagnet instance with SQLcl: as ADMIN, `@01_create_app_user.sql` and `@02_load_onnx_model.sql`; as MAGNET, `@03_schema.sql`. After the migration, `@04_embeddings_and_index.sql` and `@05_similarity_query.sql` |
| Roll out the MyMagnet app patch and migrate SQLite data | Changing the app repo and the running instances is out of scope for autonomous work; the patch hasn't been run against a real database | Follow `lab-capstone-adb-stack/app-patch/README.md`: set `MAGNET_DB_DSN`/`MAGNET_DB_PASSWORD` in `/etc/magnetlookup/env`, `git apply mymagnet-adb.patch`, run `migrate_sqlite_to_adb.py` on instance 1 and then with `--merge` on instance 2, then `systemctl disable --now magnetlookup.timer` on instance 2 |
