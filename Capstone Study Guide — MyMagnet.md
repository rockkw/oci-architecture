# Capstone Study Guide — MyMagnet (1Z0-997-26)

#certs #7_mystudy

The MyMagnet capstone ([CAPSTONE.md](terraform/CAPSTONE.md)) takes one real app, a two-node Ubuntu A1 deployment behind a public load balancer in us-phoenix-1, and adds an Autonomous AI Database with vector search, an Object Storage → Events → Function enrichment pipeline, vLLM on an OKE GPU pool, and observability plus an HA/DR design. The stacks are written up in [LABS.md](terraform/LABS.md) under `lab-mymagnet-stack` and the `lab-capstone-*` entries. This guide sorts what happened by exam domain, heaviest domain first (weights from [[OCI Architect Professional Tips]] Section 6). Every item is tagged:

- **LIVE**: seen against the real tenancy.
- **CODE**: the fix is written in Terraform, but the repo doesn't record it being applied.
- **DESIGN**: validated and planned, or designed, but never deployed.

Read an incident, cover the "lesson", and see whether you can name the OCI rule. Then take the quiz. Some claims are still unverified in the repo, and they stay marked that way here.

---

## 1. Security — 25%

| Item | Status | What happened | Exam lesson |
|---|---|---|---|
| CA can't reach its Vault key | LIVE failure; fix **not yet verified** | A CA created through the CLI settled in `FAILED` with `Authorization failed or requested resource not found: Key Id <key OCID>`. Two policies were tried: `Allow service certificates to use keys …` and `… use key-delegate …`. Both were created in the home region, both had propagated to Phoenix, and both failed the same way. | The **likely** root cause is that the CA calls Vault as its **own resource principal**. The fix to try is a dynamic group `ALL {resource.type = 'certificateauthority', resource.compartment.id = '<compartment>'}` with `use keys` and `manage objects`, and the CA `depends_on` the policy. This matches the `OCI-SM-CA-DG` dynamic group and the MyLearn skill-check answer ("the CA makes API calls to Vault"). HTTPS was dropped in the meantime. See [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]]. |
| CA create returned `400 "Unable to process JSON input"` | LIVE | Two separate bugs. (1) Terraform's `timestamp()` is unknown at plan time, so the value was missing from the request. (2) `timeOfValidityNotAfter` needs milliseconds: `…17Z` was rejected and `…17.000Z` was accepted. Even with both fixed, Terraform still failed while the raw CLI was accepted, so the repo suspects an unconfirmed provider bug. | Bisect against the raw API with `--from-json`. Poll `lifecycle-state` after `CREATING`, because the real error only showed up once the CA reached `FAILED`. |
| No egress from private instances | LIVE, fixed | The LB redesign set `assign_public_ip = false`, but the subnet still routed `0.0.0.0/0` to an **Internet Gateway**. cloud-init's `git clone` of GitHub timed out with "Network is unreachable", nginx was never installed, and the LB showed `CRITICAL / CONNECT_FAILED`. The fix moved both instances to `lab-private-subnet` (10.0.2.0/24, route to a **NAT Gateway**). `subnet_id` can't be changed in place, so both instances were **replaced**. | An IGW only gives egress to VNICs that have a public IP. Private instances need NAT for internet access, and the Service Gateway only reaches Oracle services. The LB keeps its own reserved public IP. See [[9. Networking — OCI VCN, DRG, Gateways, Load Balancers]]. |
| NSG allowed port 80, but connections were reset | LIVE, fixed | Oracle's Ubuntu image ships its own `iptables` rules that allow only SSH. `curl localhost` worked while `curl <public-ip>` reset. The fix was `iptables -I INPUT … ACCEPT` plus `netfilter-persistent save`. | The NSG or security list **and** the host firewall must both allow the traffic. AWS has no host-firewall equivalent here. |
| IAM writes from a Phoenix stack | LIVE | IAM create, update and delete calls must go to the home region (us-ashburn-1). Otherwise they fail with a hard 403. Every stack puts its dynamic groups and policies on a `provider "oci" { alias = "home" }`. Policies then take time to replicate to Phoenix: the CA retries waited for that, and LABS.md warns that the first upload after an apply may fail until IAM propagates. | Author IAM in the home region and expect replication lag before the policy takes effect in other regions. See [[AWS to OCI Exceptions]]. |
| Stale instance dynamic group | LIVE, fixed | `mymagnet-instance-dyn-grp` matched instance OCIDs that no longer existed after the subnet fix replaced the instances, so neither live instance could reach the backup bucket. Fixed in the 2026-09-24 apply. | Rules that match `instance.id` break when an instance is replaced. Matching on compartment or tag is more durable. (The multi-`instance.id` `ANY {}` form itself is flagged as unverified in LABS.md, though it has matched in practice.) |
| Reserved public IP drift | LIVE, fixed | Every plan wanted to null `private_ip_id` on the reserved IP, and the API refused with `404 … managed by <the LB>`. Fixed with `ignore_changes = [private_ip_id]`. | A public IP that the LB manages can't be reassigned by the user. |
| `cloudEvents` needs its own grant | DESIGN | `lab-capstone-enrich-stack` adds `Allow service cloudEvents to use functions-family in compartment …`. No such statement existed in the tenancy. Without it, the rule matches but the invocation is denied. | Events invokes Functions as a **service** principal. The function's own dynamic group is a separate thing and covers what the function can call. See [[14. Serverless — OCI Functions, Events, API Gateway]]. |
| Least-privilege secrets | DESIGN | The function reads the vLLM API key through its resource principal, with `read secret-bundles` on that one secret. The instances can read only `mymagnet-adb-app-password`. The ADB ADMIN password comes from a Vault secret (`secret_id`). | Keep secrets out of function config maps and plan output, and scope policies to a single secret. |
| API key on the internal vLLM LB | DESIGN | The NSG allows only 10.0.2.0/24, but VCN-native pod IPs come from that same subnet, so every OKE pod can reach the LB. vLLM therefore runs with `--api-key`. | Network scoping alone doesn't separate workloads that share a subnet. Add application-level auth. |

## 2. Cloud-Native — 20%

| Item | Status | What happened | Exam lesson |
|---|---|---|---|
| Events rule never fires | DESIGN (from docs) | Object Storage emits object events only when the bucket has `object_events_enabled = true`, and the default is false. `lab-document-understanding-stack` doesn't set it, so its rule would never fire. The enrich stack sets it and also filters on `additionalDetails.bucketName`. | "Emit Object Events" is a bucket setting. Write output to a **different** bucket so the function can't trigger itself. |
| Event → Function → LLM with a placeholder | DESIGN (9 unit tests pass; the image was built locally but not pushed) | While `llm_endpoint` is empty the function writes placeholder tags, and on a timeout it writes `status = "llm_error"`. The Functions shape is `GENERIC_X86`, so the image was built with `--platform linux/amd64` on Apple Silicon. `source_details { source_type = "CONTAINER_IMAGE" }` replaces the deprecated `image`. The function timeout is capped at 300 s. | The image must already exist in OCIR in the function's region before `oci_functions_function` can be applied. |
| Self-hosted model on OKE behind an internal LB | LIVE (2026-09-25) | Switched from vLLM on a GPU to **llama.cpp on CPU** (no-GPU decision): Qwen2.5-1.5B-Instruct Q4_K_M on one A1 node (4 OCPU / 12 GB, label `workload=llm`, arm64 image). Internal LB `10.0.2.231`: `/health` 200, no key 401, chat at ~24.5 tokens/s. Service annotations: `oci-load-balancer-internal: "true"` and `oci-load-balancer-subnet1` set to the private subnet (without it, the LB lands in the cluster's **public** `service_lb_subnet_ids`); `security-rule-management-mode: "None"` so all rules live in Terraform. The LB health-checks kube-proxy on 10256, not the app. | Know the CCM annotations. NSG rules and security-list rules are combined. A small quantized model on Arm CPUs is a valid cheap option (~$0.06/h vs ~$2/h for an A10). Delete the Service before `terraform destroy`, because the LB's VNIC still holds the NSG. See [[12. Containers — OCI OKE, Container Instances, OCIR]]. |
| GPU nodes and quota | LIVE, then removed | `gpu-a10-count` is 32 per AD in Phoenix, with 32 available in PHX-AD-1. GPU nodes join `lab-oke-workers-nsg`, which avoids the CPU pool's earlier register timeout. The boot volume was raised to 150 GB with `oci-growfs`, because the vLLM image is about 20 GB. | Check service limits before a GPU apply. An A10 costs about $2/h, so tear it down the same day. A GPU pool was created and destroyed within ~10 minutes; `terraform apply` must finish before a destroy, because killing it mid-create leaves an untracked, billing node. |
| `kubectl logs`/`exec` time out, pods run fine | LIVE, fixed | `dial tcp <node>:10250: i/o timeout`. The workers NSG allowed the control plane in on 10256 (health) but not **10250** (kubelet API), which the API server uses for logs, exec and port-forward. Added `workers_ingress_from_cp_kubelet`. | With NSGs, OKE workers need ingress from the control plane on at least 10250 (verified here), and egress to it on 6443 and 12250. Serving traffic doesn't use 10250, so the gap hides until you debug. |
| Image drift would replace the boot volume | LIVE (seen in `plan`), fixed in code | The Ubuntu image data source started returning a newer build, and a changed `source_id` replaces the boot volume. `lifecycle { ignore_changes = [source_details[0].source_id] }` was added to both instances. | IaC guardrail: never let an image lookup quietly wipe a stateful instance. |
| Silent cloud-init failure | LIVE, fixed | A rendered `Ubuntu 24.04` line at column 1 broke the YAML, and cloud-init treated the whole config as empty with no boot error. Fixed by base64-encoding the value. The `awscli` apt package doesn't exist on Ubuntu 24.04 ARM, which aborted `setup.sh`. | `validate` and `plan` can't catch errors inside user data. |

## 3. Databases — 20%

All of this is **DESIGN**. `lab-capstone-adb-stack` was validated and planned (10 to add) but not applied.

- **Autonomous AI Database 26ai.** `oci db autonomous-db-version list` (LIVE, read-only) showed 19c, 23ai and 26ai, with 26ai as `is-default-for-paid`. The database uses 2 ECPUs (the minimum) and 20 GB, with auto-scaling off. The 20 GB minimum is **unverified**. See [[6. Databases — OCI Database, NoSQL, Caching, DR]].
- **Why not Always Free.** Always Free is available only in the home region (Ashburn, while the app runs in Phoenix). It can't use a private endpoint or sit in a VCN, it stops after 7 idle days, and it may be reclaimed after 90.
- **Private endpoint in 10.0.2.0/24.** The NSG opens TCP **1522** from the subnet only. mTLS uses 1522, and TLS uses 1521 or 1522. With `is_mtls_connection_required = false`, python-oracledb Thin mode connects with no wallet. NSG rules are stateful, so no egress rule is needed for replies.
- **Vault secrets need an AES key.** The existing RSA key (made for the CA) can't encrypt secrets, so the stack adds `mymagnet-secrets-key` (AES-256).
- **Embeddings in the database.** `DBMS_VECTOR.LOAD_ONNX_MODEL_CLOUD` reads the model from a read-only PAR with `credential => NULL`. The column is `VECTOR(384, FLOAT32)`, filled by `VECTOR_EMBEDDING()`, with an HNSW index using `DISTANCE COSINE`. Without `ROUTE_OUTBOUND_CONNECTIONS = ENFORCE_PRIVATE_ENDPOINT`, `DBMS_CLOUD` traffic uses Oracle's service network.
- **Select AI with vLLM.** A `provider_endpoint` can point at any OpenAI-compatible server. A private endpoint also needs `ROUTE_OUTBOUND_CONNECTIONS = 'PRIVATE_ENDPOINT'` and `APPEND_HOST_ACE(private_target => TRUE)`. **Unverified:** whether Select AI requires HTTPS.
- **One shared database removes the need for sticky sessions**, and the scraper timer should then run on one node only.
- **Unverified list in LABS.md:** the `.onnx` file name inside the zip, `DB_DEVELOPER_ROLE` including `CREATE MINING MODEL`, DML on tables with an HNSW index in 26ai, `VECTOR_EMBEDDING` inside `MERGE`, a bind variable in `FETCH APPROX FIRST ? ROWS`, and `START WITH LIMIT VALUE`.

## 4. Observability — 20%

`lab-capstone-observability-stack` was **applied on 2026-09-25**. It created a log group, 3 custom logs with agent configurations, 3 alarms (all OK), a Notifications topic with an email subscription (still `PENDING` until the link is clicked), a log-archive bucket with a lifecycle rule, and 4 IAM resources. LABS.md still labels this stack "Not applied"; CAPSTONE.md is the newer record.

| Item | Status | What happened | Exam lesson |
|---|---|---|---|
| Custom Logs Monitoring plugin on A1 | LIVE; contradicts the docs | Oracle's plugin docs say the plugin isn't supported on Ampere A1. `oci instance-agent plugin list` nevertheless showed it **RUNNING** on both A1 instances (a correction recorded on 2026-09-25). | For the exam, remember the documented rule: the plugin isn't supported on A1, so use a manual agent install. The lab shows why you check live state as well. See [[8. Management and Governance — OCI Resource Manager, OS Management Hub, Observability]]. |
| Custom logs stay empty | LIVE, **unresolved** | The agent configurations are `VALID`/`ACTIVE`, the dynamic group matches both instances, and `use log-content` exists. Still, no entries arrived in the ~25 minutes after apply. The suspects (nginx logs readable only by the `adm` group, or the app path glob not matching) are **unconfirmed**. | Custom logs need four things: a dynamic group as the host group, `use log-content`, an agent configuration, and a running agent that can read the files. |
| Connector Hub rejected an empty source | LIVE | Creating the connector failed with "No log sources found to be read". It's now gated behind `enable_log_connector` (default false) and will be enabled once logs arrive. | Connector Hub needs source data to exist. A Logging source needs no extra policy. An Object Storage target needs the `any-user … request.principal.type='serviceconnector'` policy. Batch rollover is at most 7 minutes. |
| Lifecycle rule service permission | LIVE (applied 2026-09-25) | Object Lifecycle Management acts as the Object Storage **service**, so it needs `Allow service objectstorage-us-phoenix-1 to manage object-family` (Oracle says to put it in the tenancy root). None existed for Phoenix. The lifecycle policy `depends_on` it, yet the first apply still failed with `400-InsufficientServicePermissions`: the policy was one second old and hadn't propagated from Ashburn. The retry a few minutes later succeeded. `depends_on` orders creation; it doesn't wait for IAM propagation. | Objects move to Archive at 30 days and are deleted at 365. Archive has a 90-day minimum charge, so keep delete ≥ archive + 90. |
| Run Command stuck at `ACCEPTED` | LIVE symptom; policy applied, fix not yet confirmed | Before the NAT fix, commands sat at `ACCEPTED` and `plugin list` came back empty, because an instance with no egress can't reach the agent endpoints. Commit `dad9e91` adds `Allow dynamic-group mymagnet-instance-dyn-grp to use instance-agent-command-execution-family … where request.instance.id = target.instance.id`. Without it, the agent can't fetch commands. Applied and read back on 2026-09-25, but a command created a few minutes later was still `ACCEPTED` after several minutes of polling, so whether this alone fixes it is unconfirmed. | Run Command needs egress, a running agent, **and** this IAM grant. |
| Debugging with no SSH and no public IP | LIVE | `console-history capture` plus `get-content` with `--offset`/`--length` (the default returns only the first 10 KB) pulled the cloud-init output without logging in. The console connection needed an **RSA** key, because ed25519 was rejected. | The serial console history is a login-free diagnostic path. |
| Alarms | LIVE (applied, OK) | `unhealthyBackendServers[1m]{…}.max() > 0` (CRITICAL, 5 min pending), backend `httpResponses5xx` sum > 5, and `CpuUtilization[5m]{resourceId =~ "id1|id2"}.mean() > 80` with per-dimension notifications. The Compute Instance Monitoring plugin **is** supported on A1. | MQL `=~` with `|` covers several resources in one alarm, and per-dimension notifications send one message per instance. |

## 5. HA/DR — 15%

| Item | Status | What happened | Exam lesson |
|---|---|---|---|
| Both instances in one fault domain | LIVE, fixed | State showed both nodes in PHX-AD-1 / FAULT-DOMAIN-2. The apply on 2026-09-24 pinned `mymagnet_1` to FD-1 and `mymagnet_2` to FD-2. OCI moves a running instance by stopping it, moving it and restarting it (instance 1's backend briefly showed `WARNING`). Afterwards both backends were `OK` and `curl` returned 200. | Fault domains give anti-affinity inside one AD, and each AD has 3. Moving to another **AD** replaces the instance, with a new IP and empty local data. If the target FD has no A1 capacity, the instance stays stopped. See [[3. Compute — OCI Compute, Instance Pools, Load Balancers, Volumes]]. |
| Per-node SQLite | LIVE (accepted risk) | Two independent databases with sticky sessions, so a failed node loses its data until Phase 2 moves to ADB. | The data tier sets the RPO, and more app nodes don't change it. |
| Bucket replication Phoenix → Ashburn | DESIGN | Needs the same `objectstorage-us-phoenix-1 manage object-family` service policy. The target bucket is read-only until the replication policy is deleted, which is the promotion step. | Replication is asynchronous, typically minutes. Know when to use replication and when to use backup. |
| DNS failover | DESIGN, **blocked** | Traffic Management FAILOVER policy with a health check on `/` and a TTL of about 30 s. It needs a public DNS zone, and none is managed in OCI. | RTO ≈ failed checks × interval + TTL. |
| Autonomous Data Guard | DESIGN | Local standby: automatic failover, RPO 0, RTO 2 min. Cross-region standby in Ashburn: RPO ≤ 1 min, RTO < 10 min, **manual failover only**. | Oracle's ADB doc numbers. Backup-based DR is cheaper, with a higher RTO. |
| Full Stack DR | DESIGN | Plan order: precheck, switch over the ADB first, start compute from replicated volume groups, update the LB backend set, repoint the bucket, then let DNS move. A Failover plan skips the orderly shutdown and is started by a person. Run a precheck monthly and a drill quarterly. **Unverified:** whether buckets can be DR Protection Group members. | See [[Lab 2 - OCI Architect Pro Exam - HADR Design]]. |

---

## Practice questions

**Q1.** A team creates a root CA in OCI Certificates, signed by a key in OCI Vault. The CA settles in `FAILED` with "Authorization failed or requested resource not found: Key Id …". They already have `Allow service certificates to use keys in compartment X`. What should they do?
A. Replace it with `Allow service certificates to use key-delegate in compartment X`
B. Create a dynamic group that matches `resource.type = 'certificateauthority'` in the compartment, and grant it `use keys` and `manage objects`
C. Import the certificate as PEM directly into the load balancer
D. Grant the Administrators group `manage vaults` in the tenancy

**Q2.** Two web servers were moved behind a public load balancer and set to `assign_public_ip = false`. Their subnet's route table still sends `0.0.0.0/0` to an Internet Gateway. cloud-init now fails to clone a GitHub repo with "Network is unreachable". What is the best fix?
A. Add an NSG egress rule for TCP 443 to 0.0.0.0/0
B. Route `0.0.0.0/0` through a Service Gateway
C. Put the instances in a private subnet whose default route points to a NAT Gateway
D. Attach a second Internet Gateway to the VCN

**Q3.** An NSG allows TCP 80 from the LB subnet to an Ubuntu instance built from an Oracle platform image. `curl http://localhost/` works on the instance, but connections from the LB are reset. What is the most likely cause?
A. The security list is stateless
B. The NSG must be attached to the LB, not the VNIC
C. The LB health check uses HTTPS
D. The image's own iptables rules allow only SSH inbound

**Q4.** A Terraform stack deploys compute in us-phoenix-1 and also creates a dynamic group and a policy. The home region is us-ashburn-1. The IAM resources fail with 403 NotAllowed. What should the architect do?
A. Create the IAM resources in a child compartment
B. Subscribe the tenancy to us-phoenix-1 again
C. Use a second provider aliased to us-ashburn-1 for the IAM resources, and allow time for replication
D. Grant the Terraform user `manage all-resources` in Phoenix

**Q5.** An Events rule on `com.oraclecloud.objectstorage.createobject` matches uploads, but the target function is never invoked. The function's dynamic group can read the bucket. Which statement is missing?
A. `Allow service cloudEvents to use functions-family in compartment X`
B. `Allow dynamic-group fn-dg to use functions-family in compartment X`
C. `Allow service objectstorage-us-phoenix-1 to manage object-family in compartment X`
D. `Allow any-user to use fn-invocation where request.principal.type = 'bucket'`

**Q6.** A bucket-triggered pipeline was deployed. The Events rule and policies are correct, but no event is ever emitted when objects are uploaded. What is the cause?
A. The bucket is in the Archive tier
B. The Events rule is missing an action
C. The bucket's "Emit Object Events" setting (`object_events_enabled`) is off, which is the default
D. Object Storage events are published only to Streaming

**Q7.** A vLLM Service on OKE must get an OCI load balancer that is reachable only inside the VCN and sits in a specific private subnet. Without extra configuration, the LB lands in the cluster's public LB subnet. Which annotations fix this?
A. `oci.oraclecloud.com/load-balancer-type: "nlb"` only
B. `service.beta.kubernetes.io/oci-load-balancer-internal: "true"` and `service.beta.kubernetes.io/oci-load-balancer-subnet1: <private subnet OCID>`
C. `oci.oraclecloud.com/security-rule-management-mode: "NSG"`
D. `oci.oraclecloud.com/reserved-private-ips` only

**Q8.** `terraform plan` on a stateful two-node deployment suddenly shows each instance's boot volume being replaced. No code changed, but the image data source now returns a newer platform image. What is the safest change?
A. Add `lifecycle { ignore_changes = [source_details[0].source_id] }` to the instances
B. Run `terraform apply -replace` during a maintenance window
C. Move the instances to another availability domain
D. Remove the instances from state with `terraform state rm`

**Q9.** An app in us-phoenix-1 needs an Autonomous Database reachable only through a private endpoint in its VCN. To save cost, the team proposes Always Free. The tenancy's home region is us-ashburn-1. Why won't that work?
A. Always Free doesn't support vector search
B. Always Free supports only the Data Warehouse workload
C. Always Free requires mTLS on port 1521
D. Always Free is home-region only and can't be provisioned with a private endpoint in a VCN

**Q10.** Terraform creates a Vault secret for an ADB password with an existing Vault key that was made for a certificate authority. Secret creation fails. What is the likely reason?
A. Secrets must be stored in a Virtual Private Vault
B. The key is RSA, and secrets must be encrypted with an AES key
C. Secrets can't be referenced by ADB `secret_id`
D. The key is in a different compartment

**Q11.** An ADB has a private endpoint and a python-oracledb Thin-mode client that must connect without a wallet. What configuration is required?
A. `is_mtls_connection_required = false`, and an NSG allowing TCP 1522 (or 1521) from the app subnet
B. mTLS required, NSG open on 1521
C. A public endpoint with an ACL for the NAT gateway IP
D. `ROUTE_OUTBOUND_CONNECTIONS = ENFORCE_PRIVATE_ENDPOINT`

**Q12.** Creating a Connector Hub connector from a custom-log log group to Object Storage fails with "No log sources found to be read". The bucket policy for `serviceconnector` exists. What should the architect do?
A. Add a policy that lets the connector read the log group
B. Lower `batch_rollover_time_in_ms` below 7 minutes
C. Get entries flowing into the custom logs first (agent running, `use log-content`), then create the connector
D. Change the target to Logging Analytics

**Q13.** Private instances have NAT egress and a running Oracle Cloud Agent, but Run Command jobs stay in `ACCEPTED` forever. What is missing?
A. A Bastion session to each instance
B. `Allow dynamic-group <instances> to use instance-agent-command-execution-family … where request.instance.id = target.instance.id`
C. The Custom Logs Monitoring plugin
D. A public IP on each instance

**Q14.** Two LB backends in the same availability domain both run in FAULT-DOMAIN-2. The requirement is to survive a single rack failure with the least disruption and no data loss. What should the architect do?
A. Move one instance to another availability domain
B. Put both instances in an instance pool in the same fault domain
C. Change one instance's fault domain so the two are in different fault domains, keeping the other serving during the move
D. Replace them with a single larger shape

**Q15.** An ADB needs a standby in a second region. The business asks whether cross-region failover will happen automatically. What is correct?
A. Yes. Autonomous Data Guard fails over automatically to any standby.
B. No. Cross-region Data Guard isn't supported for Autonomous Database.
C. Yes, if Full Stack DR is configured with a Failover plan.
D. No. A local standby fails over automatically, but failover to a cross-region standby is manual (RPO ≤ 1 min).

### Answer key

1. **B** — The CA calls Vault as its own resource principal, so it needs a dynamic group. Both `service certificates` grants failed in the lab. (In the lab this is still the likely fix, not yet applied.)
2. **C** — An IGW gives egress only to VNICs with a public IP. NAT gives private instances outbound access. A Service Gateway reaches only Oracle services.
3. **D** — Oracle's Ubuntu image ships host iptables that allow only port 22. Both the NSG and the host firewall must allow the traffic.
4. **C** — IAM writes must go to the home region and then replicate to other regions.
5. **A** — Events invokes the function as the `cloudEvents` service principal. The function's own dynamic group doesn't cover the invocation.
6. **C** — Object events are off by default for each bucket. `lab-document-understanding-stack` has exactly this gap.
7. **B** — The `internal` annotation makes the LB private, and `subnet1` places it in the chosen subnet.
8. **A** — A changed `source_id` replaces the boot volume, so ignoring it keeps the running disks.
9. **D** — Always Free is home-region only and can't use a private endpoint or sit in a VCN.
10. **B** — Vault secrets require an AES key, and the CA key is RSA.
11. **A** — TLS without a wallet is allowed on a private endpoint once mTLS isn't required. Port 1522 works for both TLS and mTLS.
12. **C** — Connector Hub rejects an empty log source. A Logging source needs no extra policy.
13. **B** — Without this grant the agent can't fetch its commands, so they stay `ACCEPTED`. (The lab first saw this when the instances had no egress.)
14. **C** — Fault domains give anti-affinity inside an AD. Moving to another AD replaces the instance and its local data.
15. **D** — Autonomous Data Guard fails over automatically only to a local standby. Cross-region failover is started by a person.

---

## Commands worth knowing (used in the capstone)

```bash
# Agent and Run Command
oci instance-agent plugin list --instanceagent-id <instance> --compartment-id <c>
oci instance-agent command create ...            # Run Command, stuck at ACCEPTED in the lab
# Debugging without a login
oci compute console-history capture ...          # then get-content with --offset/--length (the default is only 10 KB)
oci compute instance-console-connection create ...   # needs an RSA key; ed25519 is rejected
oci lb backend-set-health get ...                # CRITICAL/CONNECT_FAILED -> WARNING -> OK
# Certificates: bisect against the raw API
oci certs-mgmt certificate-authority create-root-ca-by-generating-config-details --from-json file://ca.json
# Read-only checks before designing or applying
oci db autonomous-db-version list --db-workload OLTP --region us-phoenix-1
oci limits resource-availability get --service-name compute --limit-name gpu-a10-count \
  --availability-domain bXWp:PHX-AD-1 --compartment-id <c> --region us-phoenix-1
oci iam policy list ...                          # check whether a service policy already exists
oci ons subscription list -c <c> --region us-phoenix-1   # PENDING until the email link is clicked
# Objects and PARs
oci os object put -bn mymagnet-results --file r.txt --region us-phoenix-1
oci os preauth-request create -bn mymagnet-onnx-models --name onnx-load --access-type ObjectRead \
  --object-name all_MiniLM_L12_v2.onnx --time-expires <+1 day> --region us-phoenix-1
oci db autonomous-database stop --autonomous-database-id <adb>   # a stopped ADB bills storage only

# Terraform
terraform show -json <plan>                      # found the missing timestamp in the request body
terraform apply -target=oci_core_instance.mymagnet_1 -target=...   # scoped apply around a broken chain
terraform plan -var enable_log_connector=true -out=obs.tfplan
terraform output -raw vllm_manifest > /tmp/vllm.yaml
kubectl apply --dry-run=client -f /tmp/vllm.yaml
```

Related: [[Active OCI Architect Professional Certification Plan — 1Z0-997-26]], [[MyLearn Skill Check Questions]], [[OCI Architect Professional Tips]].
