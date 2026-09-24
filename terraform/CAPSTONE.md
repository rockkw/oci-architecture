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
3. **Self-hosted model on OKE.** vLLM on `lab-oke-gpu-stack`'s A10 node pool,
   behind an internal LB. It takes the place of the hosted OCI Generative AI
   service, which the capstone deliberately doesn't use.

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
                                     OKE GPU node pool (vLLM)
```

## Phases

| # | Phase | Exam domains | Reuses | Status |
|---|---|---|---|---|
| 1 | Fix MyMagnet blockers (HTTPS certificate chain, app reachability) | Security | `lab-mymagnet-stack` | Reachability fixed; HTTPS removed in config, apply deferred (see Deferred) |
| 2 | SQLite → Autonomous AI Database (26ai) + AI Vector Search | Databases | `lab-basedb-stack` (network pattern), `lab-mymagnet-stack` (Vault, dynamic group) | `lab-capstone-adb-stack` written: validate clean, plan 10 to add. `sql/` scripts and MyMagnet app patch drafted. Apply, SQL and app rollout deferred (see Deferred) |
| 3 | Enrichment pipeline, with a placeholder tag at first so it's testable without a GPU | Cloud-Native, Security | `lab-document-understanding-stack`, `lab-func-stack` | `lab-capstone-enrich-stack` written: validate clean, plan 9 to add, 9 unit tests pass. Image build/push and apply deferred (see Deferred). ADB write is a marked hook in func.py |
| 4 | vLLM on OKE GPU behind an internal LB; point the Function at it | Cloud-Native | `lab-oke-stack`, `lab-oke-gpu-stack` | Built and validated (`lab-capstone-vllm-stack`); not applied (see Deferred) |
| 5 | Observability (UMA logs, custom metrics, alarms → Notifications) and HA/DR (fault domains, cross-region bucket replication, DNS failover) | Observability, HA/DR | Lab 2 design | `lab-capstone-observability-stack` written, plan 19 to add, apply deferred; HA/DR designed below (not provisioned) |

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
from state, so `terraform plan` runs with no `-var` flags. The current plan is
0 to add, 1 to change (the instance dynamic group), 1 to destroy (the 443 NSG
rule).

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
  **Still unverified:** whether Select AI requires HTTPS for `provider_endpoint`.
  If it does, the Phase 4 LB needs a certificate, which brings back the Phase 1
  CA problem. The script also needs an ADB NSG egress rule to the LB.
- **Naming:** Oracle's current docs call the service "Autonomous AI Database
  26ai" ([May 2026 release note](https://docs.oracle.com/en-us/iaas/releasenotes/autonomous-database-serverless/2026-05-outbound-conn-options.htm)),
  and 26ai is now the paid default (checked above). The vector features are the same.

### Phase 4 cost control

`VM.GPU.A10.1` costs roughly $2/hour at list price (confirm on Oracle's price
list). Apply `lab-oke-gpu-stack` only while working on Phase 4 and destroy it
afterwards. GPU quota was checked on 2026-09-24: Ashburn allows 16–32 A10s per
availability domain, so no limit increase is needed.

The cluster turned out to be in **Phoenix**, not Ashburn. Phoenix was checked too:
`gpu-a10-count` is 32 per AD, with 32 available and 0 used in PHX-AD-1, where the
pool goes.

### Phase 4 notes: vLLM on OKE

Stack: [`lab-capstone-vllm-stack`](lab-capstone-vllm-stack/), fully documented in
[LABS.md](LABS.md#lab-capstone-vllm-stack) with the bring-up, smoke-test and
tear-down runbook.

- **Same VCN, same subnet.** `lab-oke-cluster` is in us-phoenix-1, in `lab-vcn`,
  which is MyMagnet's VCN. Its workers are in `10.0.2.0/24` next to the MyMagnet
  instances. No peering or move is needed.
- **Model:** `Qwen/Qwen2.5-7B-Instruct`, pinned by revision. It's Apache-2.0 and not
  gated, and its ~15 GB of bf16 weights fit one A10. vLLM runs with
  `--max-model-len=8192 --gpu-memory-utilization=0.90`.
- **Endpoint:** an internal flexible LB at `http://<10.0.2.x>/v1/...`, reachable
  only from `10.0.2.0/24` (enforced by an NSG). Clients authenticate with a bearer
  token (`--api-key`), because every OKE pod also gets an IP in that subnet.
- **Upstream fixes:** GPU nodes now join `lab-oke-workers-nsg`, which avoids the
  CPU pool's old register-timeout. The boot volume is 150 GB, grown with
  `oci-growfs`.
- **Select AI:** the ADB private endpoint in `10.0.2.0/24` is covered. Whether
  Select AI accepts a plain-HTTP `provider_endpoint` is unconfirmed. HTTPS is
  future work.

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
| Fault domains | **Both instances sit in PHX-AD-1 / FAULT-DOMAIN-2**, so one rack fault can take down both (checked in state on 2026-09-24). `lab-mymagnet-stack` now pins `mymagnet_1` to FD-1 and `mymagnet_2` to FD-2 (not yet applied). Oracle updates this in place: a running instance is stopped, moved and restarted. Keep the other node serving during the move. If the target FD has no A1 capacity, the instance stays stopped. | Per-node SQLite on the failed node, until Phase 2 moves data to ADB | ≈ health-check interval (LB drops the backend) | FDs = anti-affinity within one AD. Phoenix has 3 ADs, but moving ADs replaces the instance (new IP, empty SQLite) |
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

## Deferred

Items blocked during autonomous work. Each needs a person to run or approve it.

| Item | Why it's deferred | How to finish |
|---|---|---|
| Apply `lab-mymagnet-stack` (removes the 443 NSG rule, fixes the stale instance dynamic group, moves instance 1 to FD-1) | Auto mode blocks unattended `terraform apply`, IAM changes, and removing TLS | `cd terraform/lab-mymagnet-stack && terraform plan && terraform apply` |
| HTTPS on the LB | Removed by decision; the CA fix needs an IAM grant | Re-add the CA chain with the dynamic group above |
| Phase 4: bring up the GPU pool and vLLM, then run the smoke test | Needs `terraform apply` and `kubectl apply` against the real cluster, and starts GPU billing (~$2/h) | Follow LABS.md, "lab-capstone-vllm-stack" runbook: `(cd terraform/lab-oke-stack && terraform apply)`, `(cd terraform/lab-oke-gpu-stack && terraform apply)`, `(cd terraform/lab-capstone-vllm-stack && terraform apply && terraform output -raw vllm_manifest > /tmp/vllm.yaml)`, `kubectl create namespace vllm`, create the `vllm-api-key` Secret, `kubectl apply -f /tmp/vllm.yaml`, run the `curl`, then tear down the same day |
| Phase 4: can Select AI call vLLM over HTTP? | Unverified. Select AI may require HTTPS, and the private CA certificate is blocked on IAM | With vLLM up, create a Select AI profile with `provider_endpoint` = `http://<LB_IP>` from the ADB. If it rejects HTTP, add TLS at the LB (LABS.md, "HTTPS later") |
| Apply `lab-capstone-observability-stack` (19 resources, 4 of them IAM) | Auto mode blocks `terraform apply` and IAM changes | `cd terraform/lab-capstone-observability-stack && terraform plan -var alarm_email=<you@example.com> && terraform apply -var alarm_email=<you@example.com>`, then click the email confirmation link |
| Install the Unified Monitoring Agent on both A1 instances | The Custom Logs Monitoring plugin isn't supported on Ampere A1; the manual aarch64 install needs SSH plus an `oci session authenticate` token | On each instance: `oci os object get --namespace axmjwnk4dzjv --bucket-name unified-monitoring-agent-ub-bucket --name unified-monitoring-agent-ub-24-<ver>.aarch64.deb --file uma.deb --auth security_token && sudo dpkg -i uma.deb` (get `<ver>` from `versionInfoV2.yml` in bucket `unified-monitoring-agent-config`) |
| Spread the MyMagnet instances across fault domains | Config done (FD-1/FD-2 pinned in `lab-mymagnet-stack`; plan confirms an in-place move of instance 1). Apply needs a person and briefly stops instance 1 | Included in the `lab-mymagnet-stack` apply row above (plan: 0 add, 2 change, 1 destroy) |
| Build and push the Phase 3 function image | `docker build` needs the Docker Desktop daemon, which asked for privileged access when started (needs a person); pushing images is blocked in auto mode | `cd terraform/lab-capstone-enrich-stack && docker login phx.ocir.io -u 'idtlmgo3jgde/<username>' && docker build --platform linux/amd64 -t phx.ocir.io/idtlmgo3jgde/capstone/enrich:0.0.1 . && docker push phx.ocir.io/idtlmgo3jgde/capstone/enrich:0.0.1` |
| Apply `lab-capstone-enrich-stack` (9 resources: 2 buckets, NSG + rule, Functions app + function, Events rule, dynamic group, policy) | Auto mode blocks `terraform apply` and IAM changes; needs the image above first | `cd terraform/lab-capstone-enrich-stack && terraform plan && terraform apply`, then upload a test object to `mymagnet-results` and read `enriched/<name>.enrichment.json` from `mymagnet-enrichment` (LABS.md has the commands) |
| Point the Phase 3 function at vLLM | Needs Phase 4 running, the vLLM API key stored as a Vault secret, and an apply (config + one IAM statement) | `cd terraform/lab-capstone-enrich-stack && terraform apply -var llm_endpoint=http://<internal-lb-ip> -var llm_model=qwen2.5-7b-instruct -var llm_api_key_secret_ocid=<vault-secret-ocid>` |
| Apply `lab-capstone-adb-stack` (10 resources: ADB, NSG + rule, AES key, 2 secrets, bucket, 1 IAM policy, 2 random passwords) | Auto mode blocks `terraform apply` and IAM changes, and the ADB starts paid billing (2 ECPUs) | `cd terraform/lab-capstone-adb-stack && terraform plan && terraform apply`; stop the database between sessions with `oci db autonomous-database stop --autonomous-database-id "$(terraform output -raw autonomous_database_id)"` |
| Upload the ONNX model and create its PAR | Needs the bucket from the apply above; creating objects and PARs is a write | Follow `lab-capstone-adb-stack/sql/README.md`: `curl` + `unzip` Oracle's `all_MiniLM_L12_v2_augmented.zip`, `oci os object put -bn mymagnet-onnx-models --file all_MiniLM_L12_v2.onnx --name all_MiniLM_L12_v2.onnx --region us-phoenix-1`, `oci os preauth-request create -bn mymagnet-onnx-models --name onnx-load --access-type ObjectRead --object-name all_MiniLM_L12_v2.onnx --time-expires <+1 day> --region us-phoenix-1` |
| Run the Phase 2 SQL scripts | The ADB has only a private endpoint, so the scripts must run from inside the VCN (an instance or a Bastion session) against a live database | From a MyMagnet instance with SQLcl: as ADMIN, `@01_create_app_user.sql` and `@02_load_onnx_model.sql`; as MAGNET, `@03_schema.sql`. After the migration, `@04_embeddings_and_index.sql` and `@05_similarity_query.sql` |
| Roll out the MyMagnet app patch and migrate SQLite data | Changing the app repo and the running instances is out of scope for autonomous work; the patch hasn't been run against a real database | Follow `lab-capstone-adb-stack/app-patch/README.md`: set `MAGNET_DB_DSN`/`MAGNET_DB_PASSWORD` in `/etc/magnetlookup/env`, `git apply mymagnet-adb.patch`, run `migrate_sqlite_to_adb.py` on instance 1 and then with `--merge` on instance 2, then `systemctl disable --now magnetlookup.timer` on instance 2 |
