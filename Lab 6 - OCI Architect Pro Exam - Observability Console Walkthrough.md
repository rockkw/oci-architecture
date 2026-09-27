# Lab 6 - OCI Architect Pro Exam - Observability Console Walkthrough

#7_mystudy #OCI  
**Status: ✅ COMPLETED 2026-09-27** (all Parts A–H walked through live in the Console; results below).  
**Plan item:** Close the Observability gaps from Practice Exam attempt 2 (Q6 Interval, Q8 MQL required/optional parts, Q29 agent configuration vs. Cloud Agent) by doing each thing by hand in the Console.

**Companion references:** [[8. Management and Governance — OCI Resource Manager, OS Management Hub, Observability]] (Monitoring Concepts, MQL syntax, Logging, Connector Hub); [[Active OCI Architect Professional Certification Plan — 1Z0-997-26]] items 18 and 19; the capstone's `terraform/lab-capstone-observability-stack` (which created everything you'll look at here).

**Approach:** read-only exploration of resources that already exist, plus **one throwaway alarm** you create and delete in Part C. Covers all four observability review items: MQL (A–C), logs in/out (D–E), health checks (G), detect vs. prevent (F, H). Nothing else is changed. Cost: effectively $0.

**Where:** region **US West (Phoenix)**, compartment **`sandbox`**.

| Live resource | Name |
|---|---|
| Compute instances | `mymagnet-instance-1` (FAULT-DOMAIN-1), `mymagnet-instance-2` (FAULT-DOMAIN-2) |
| Load balancer | `mymagnet-lb` (public IP `137.131.32.68`, backend set `mymagnet-backend-set`) |
| Alarms | `mymagnet-instance-cpu`, `mymagnet-lb-unhealthy-backends`, `mymagnet-lb-5xx` |
| Notifications topic | `mymagnet-alarms` (your email is subscribed and ACTIVE) |
| Log group / logs | `mymagnet-log-group`: `mymagnet-nginx-access`, `mymagnet-nginx-error`, `mymagnet-app` |
| Agent configurations | `mymagnet-nginx-access-agent-config`, `mymagnet-nginx-error-agent-config`, `mymagnet-app-agent-config` |
| Connector | `mymagnet-log-archive` (Logging → Object Storage bucket `mymagnet-log-archive`) |

---

## Part A — Service Metrics (pre-built charts)

1. ☰ → **Observability & Management → Monitoring → Service Metrics**.
2. Compartment `sandbox`, Metric namespace **`oci_computeagent`**.
3. You'll see a chart per metric (CPU Utilization, Memory Utilization, Disk Read I/O…), **one line per instance** (two lines: two metric streams).
4. On **CPU Utilization**: **Options → Edit Dimensions** → Dimension name **`resourceDisplayName`** → value **`mymagnet-instance-1`** → Save. Now one line.
5. Change it to Dimension name **`faultDomain`** → **`FAULT-DOMAIN-2`**. Still one line, but this time it's instance-2, selected by *where it runs*, not by name.
6. Clear the dimension and tick **Aggregate metric streams**: the two lines merge into one.
7. Note the per-chart **Interval** (Auto) and **Statistic** (Mean; Disk I/O charts default to **Rate**).

**What this proves:** dimensions *filter* (optional), aggregate = the *grouping* function (optional), interval and statistic are always there (required). See the Edit Dimensions screenshot in Note 8.

---

## Part B — Metrics Explorer (write the MQL yourself)

1. Monitoring → **Metrics Explorer** → **Edit queries**.
2. Query 1, Basic mode: Compartment `sandbox`, Metric namespace `oci_computeagent`, Metric name **`CpuUtilization`**, Interval **`1m`**, Statistic **`Mean`** → **Update chart**. Two lines.
3. Tick **Advanced mode**. The MQL reads `CpuUtilization[1m].mean()`: metric + interval + statistic, the minimum valid query.
4. In Advanced mode, try each edit and **Update chart** after each:
   - `CpuUtilization[5m].mean()`: fewer, smoother points (longer **interval** = wider aggregation window).
   - `CpuUtilization[1m]{faultDomain = "FAULT-DOMAIN-1"}.mean()`: one line (**dimension** filter).
   - `CpuUtilization[1m].grouping().mean()`: one merged line (**grouping**).
   - `CpuUtilization[1m].groupBy(faultDomain).max()`: one line **per fault domain** (**group by**), statistic Max.
   - `CpuUtilization[1m].percentile(0.9)`: the P90 value.
5. Try removing `[1m]` → the query is rejected: **interval is required** (this was Q8).
6. Optional: **Add Query** → namespace `oci_lbaas`, metric `HttpRequests`, then refresh `http://137.131.32.68/` in a browser a few times and watch the LB request count rise.

---

## Part C — Alarms (read one, then fire a throwaway)

**C1. Read an existing alarm.** Monitoring → **Alarm Definitions** → `mymagnet-instance-cpu`:
- Query: `CpuUtilization[5m]{resourceId =~ "<instance-1>|<instance-2>"}.mean() > 80`, the same MQL with a **condition** appended.
- Trigger delay ("pending duration"), severity, and **destination topic `mymagnet-alarms`**.
- Compare with `mymagnet-lb-unhealthy-backends`: `unhealthyBackendServers[1m]{…}.max() > 0` (namespace `oci_lbaas`).

**C2. Fire a throwaway alarm.**
1. **Create Alarm** → name **`lab6-test-alarm`**, severity Info.
2. Metric: namespace `oci_computeagent`, metric `CpuUtilization`, interval `1m`, statistic `Mean`, dimension `resourceDisplayName = mymagnet-instance-1`.
3. Trigger rule: **greater than `0`** (always true), trigger delay **1 minute**.
4. Destination: Notifications, topic **`mymagnet-alarms`**. Save.
5. Within a few minutes: **Alarm Status** shows it **Firing**, and you get an email.
6. **Delete `lab6-test-alarm`** (Alarm Definitions → ⋮ → Delete). Only that one; leave the three `mymagnet-*` alarms alone.

**What this proves:** alarm = MQL query + condition + trigger delay + Notifications topic.

---

## Part D — Logging (getting logs in)

1. ☰ → **Observability & Management → Logging → Log Groups** → **`mymagnet-log-group`**.
2. Open **`mymagnet-nginx-access`** → **Explore Log**: you'll see nginx access lines from both instances (your Part B browser refreshes should appear here).
3. Logging → **Agent Configurations** → **`mymagnet-nginx-access-agent-config`**:
   - **Host groups:** a **dynamic group** (it targets the two instances; this is how the agent knows which hosts it applies to).
   - **Agent configuration:** input type **Log path** `/var/log/nginx/access.log`, parser, and **destination log** `mymagnet-nginx-access`.
4. Compute → `mymagnet-instance-1` → **Oracle Cloud Agent** tab: **Custom Logs Monitoring** plugin *Enabled/Running* (on OCI instances, the agent arrives through this plugin).

**What this proves (Q29):** the **agent configuration** says *what to collect and where to send it*, and it applies to OCI instances **and** on-prem hosts. The **Cloud Agent plugin** is only how the agent gets onto **OCI** instances; on-prem hosts install the agent package manually.

---

## Part E — Service Connector Hub (getting logs out)

1. ☰ → **Observability & Management → Connector Hub** → **`mymagnet-log-archive`**: source **Logging** (`mymagnet-log-group`), target **Object Storage** (`mymagnet-log-archive`), status Active. Note the metrics tab (bytes read/written).
2. Storage → Buckets → **`mymagnet-log-archive`** → objects named `<connector OCID>/<start>_<end>.0.log.gz`: batched, gzipped log files, roughly every 7 minutes.
3. Bucket → **Lifecycle Policy Rules**: archive after 30 days, delete later.

**What this proves:** Connector Hub moves data *between* services (source → optional task → target) without code; "archive logs to Object Storage" = Connector Hub. Remember it refused to be created while the logs were empty.

---

## Part F — Audit (who changed what)

1. ☰ → **Observability & Management → Logging → Audit** (or Identity & Security → Audit).
2. Compartment `sandbox`, custom time range **2026-09-24 15:00–15:10 UTC**. Plain keywords fail in the search box (it always sends query-language text: `GSL: mismatched input … expecting {CAST, SEARCH, SET}`), so switch to **Advanced** and use:
   `search "<compartment OCID>/_Audit" | where data.eventName = 'UpdateInstance'`
3. Open the event from the fault-domain move of `mymagnet-instance-1`: principal (the Terraform API user), source IP, timestamp, and request details.

**What this proves:** Audit records every API call (Console, CLI, Terraform) automatically for 365 days, but it's **detective only**. Prevention = IAM least privilege, compartment quotas; fast response = Events → Notifications.

---

## Part G — Health checks: what "healthy" actually proves (Q43)

1. Networking → **Load Balancers** → **`mymagnet-lb`** → Backend Sets → **`mymagnet-backend-set`** → **Update health check** (view only, then Cancel):
   protocol **HTTP**, port **80**, URL path **`/`**, expected status **200**. This check exercises the **app** (nginx → MyMagnet); it's what caught the real `CONNECT_FAILED` outage in the capstone's Blocker 2.
2. Back in the list, open the load balancer named **`1d709505-3d32-4380-a2f1-516694e371ac`** (auto-named: created by Kubernetes for the `vllm` Service, IP `10.0.2.231`) → its backend set → health check:
   **HTTP port 10256, path `/healthz`**. That's **kube-proxy on the node**, not the model server. If llama.cpp crashed, this LB would still say healthy (Kubernetes' own readiness probe is what protects the app there).
3. Compare **Backend Health** on both: OK means "the thing the check probes answered", nothing more.

**What this proves:** a **TCP** check proves only that a port accepts connections; an **HTTP** check with path + status proves the application responds. Always ask *what* the health check actually probes.

---

## Part H — Prevention vs. detection (IAM and quotas)

1. Identity & Security → **Policies** (compartment `sandbox`) → **`mymagnet-backup-policy`**. Read its two statements:
   - `Allow dynamic-group mymagnet-instance-dyn-grp to manage objects in compartment id … where target.bucket.name = 'mymagnet-backups'`: least privilege, scoped to **one bucket**.
   - `… to use instance-agent-command-execution-family … where request.instance.id = target.instance.id`: each instance can fetch **only its own** Run Command jobs.
   Prevention pattern: humans get `read`/`inspect`, automation gets `manage`, conditions narrow the target.
2. Governance & Administration → **Tenancy Management → Quotas** → **Create Quota** (**don't save**). Type the statement to see the syntax, then **Cancel**:
   `set compute-core quota standard-a1-core-count to 4 in compartment sandbox`
   A quota **rejects** any API call that would exceed it, whoever makes it, which is how you'd stop a console shape change from adding OCPUs. Compare with Part F: Audit only *records* the change afterwards.

---

## Results (walked through live, 2026-09-27)

| Part | What we saw |
|---|---|
| A | 7 metric streams in `sandbox` (2 MyMagnet VMs, 3 OKE nodes, `bastion-target-instance`, `nsg-test-instance`). Dimension filters combine with AND; FD-1 = instance-1 + 2 OKE nodes, FD-2 = instance-2 + 3 others. Aggregate on FD-1 memory: ~31/25/10% → one line at ~22% (Mean). `instancePoolId` = Default for every instance, OKE nodes included. |
| B | Hand-written MQL: `[1m]`→`[5m]` smoothed a 10% spike to ~4.5%; `=~ "mymagnet-*"` fuzzy match; `.grouping()` and `.groupBy(faultDomain)` results agreed; P90 ≈ 2× mean; **no interval = parser error**. A UI search spiked CPU on **both** instances → LB application-cookie stickiness doesn't stick (MyMagnet sets no cookie; see `terraform/CAPSTONE.md`). |
| C | `mymagnet-instance-cpu`: 2 metric streams, 10-min trigger delay, split notifications. Test alarm `lab6-test-alarm` (`> 0`) went FIRING ~4 min after creation and emailed `Alarm: OK_TO_FIRING | CRITICAL | Lab6 Alarm CPU`; now **disabled**, kept for demos. |
| D | nginx access logs (~8 events/min baseline = LB health checks). Agent configuration: dynamic-group host group (user groups empty = how on-prem hosts would be added), log path `/var/log/nginx/access.log`, **APACHE2** parser. Cloud Agent plugins: Custom Logs Monitoring = logs, Compute Instance Monitoring = metrics. |
| E | Connector `mymagnet-log-archive`: batch 100 MB / 420000 ms (7 min); objects `<connector OCID>/<start>_<end>.0.log.gz`, ~3 KiB each (time-based flush), one 14 KiB file where real traffic happened. |
| F | Two `UpdateInstance` events, 2026-09-24 15:01:28 and 15:03:44 UTC, by Rock Whitney from 76.155.1.207 via `Oracle-GoSDK … darwin/arm` (Terraform). **`stateChange`**: `faultDomain` FAULT-DOMAIN-2 → FAULT-DOMAIN-1, `lifecycleState` STOPPING. |
| G | `mymagnet-lb`: HTTP `/` port 80, status 200, body regex `.*`, interval 30 s, timeout 3 s, 3 retries (~90 s to unhealthy). Kubernetes LB (`1d709505…`, 10.0.2.231 private): **3 backends OK** = every worker node (NodePort), checked via kube-proxy, so it stays green even if the model pod is down; the pod's readiness probe is the real guard. LB access/error service logs are *not enabled*. |
| H | `mymagnet-backup-policy` shows the least-privilege levers (subject, verb, resource type, `where`). Creating a quota from Phoenix failed: **"Please go to your home region to execute Quota operations"** (quotas, like IAM, are home-region only). Nothing was created. A 4-core A1 quota would have blocked new capacity: `sandbox` already runs ~10 A1 cores. |

Notes updated from this lab: [[8. Management and Governance — OCI Resource Manager, OS Management Hub, Observability]] (dimensions, aggregation, hand-written MQL table, alarms hands-on, custom logs and agent configuration, Connector Hub to a SIEM), [[AWS to OCI Exceptions]] (SIEM delivery, agent log shipping).

## Recall questions

1. Which three MQL components are required? Which two are optional?
2. In `CpuUtilization[5m].mean()`, which part sets the aggregation window?
3. What does ticking *Aggregate metric streams* add to the MQL?
4. Logs must be collected from **on-premises** servers and archived to Object Storage. Which two features?
5. An alarm never notifies anyone, though its Status shows Firing. What's the first thing to check?
6. Can OCI Audit stop someone from changing an instance shape?
7. The load balancer shows every backend healthy, but users get errors. Name the most likely health-check cause.

<details><summary>Answers</summary>

1. Required: metric, interval, statistic. Optional: dimensions, grouping function.
2. `[5m]`, the **interval** (not resolution).
3. `.grouping()`.
4. **Agent Configuration** (standalone Unified Monitoring Agent on the hosts) + **Service Connector Hub** (Logging → Object Storage).
5. The **Notifications** side: the alarm's destination topic and whether the subscription is **confirmed (ACTIVE)**; a PENDING email subscription receives nothing.
6. No. Audit only records. Prevent with IAM (`read`/`inspect` for humans, `manage instances` only for automation) and compartment quotas; alert with Events → Notifications.
7. The health check probes something other than the app: a **TCP** check (port open) instead of **HTTP** path + status, or, as with the Kubernetes LB here, a check against kube-proxy (`/healthz` on 10256) rather than the service itself.

</details>

## Official references
- [Monitoring Query Language (MQL) reference](https://docs.oracle.com/en-us/iaas/Content/Monitoring/Reference/mql.htm)
- [Agent management: agent configurations](https://docs.oracle.com/en-us/iaas/Content/Logging/Concepts/agent_management.htm)
- [Connector Hub overview](https://docs.oracle.com/en-us/iaas/Content/connector-hub/overview.htm)
- [Audit overview](https://docs.oracle.com/en-us/iaas/Content/Audit/Concepts/auditoverview.htm)
