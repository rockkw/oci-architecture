# Lab 6 - OCI Architect Pro Exam - Observability Console Walkthrough

#7_mystudy #OCI  
**Plan item:** Close the Observability gaps from Practice Exam attempt 2 (Q6 Interval, Q8 MQL required/optional parts, Q29 agent configuration vs. Cloud Agent) by doing each thing by hand in the Console.

**Companion references:** [[8. Management and Governance — OCI Resource Manager, OS Management Hub, Observability]] (Monitoring Concepts, MQL syntax, Logging, Connector Hub); [[Active OCI Architect Professional Certification Plan — 1Z0-997-26]] items 18 and 19; the capstone's `terraform/lab-capstone-observability-stack` (which created everything you'll look at here).

**Approach:** read-only exploration of resources that already exist, plus **one throwaway alarm** you create and delete in Part C. Nothing else is changed. Cost: effectively $0.

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
2. Compartment `sandbox`, date range **2026-09-24**, search keyword **`UpdateInstance`**.
3. Open the event from the fault-domain move of `mymagnet-instance-1`: principal (the Terraform API user), source IP, timestamp, and request details.

**What this proves:** Audit records every API call (Console, CLI, Terraform) automatically for 365 days, but it's **detective only**. Prevention = IAM least privilege, compartment quotas; fast response = Events → Notifications.

---

## Recall questions

1. Which three MQL components are required? Which two are optional?
2. In `CpuUtilization[5m].mean()`, which part sets the aggregation window?
3. What does ticking *Aggregate metric streams* add to the MQL?
4. Logs must be collected from **on-premises** servers and archived to Object Storage. Which two features?
5. An alarm never notifies anyone, though its Status shows Firing. What's the first thing to check?
6. Can OCI Audit stop someone from changing an instance shape?

<details><summary>Answers</summary>

1. Required: metric, interval, statistic. Optional: dimensions, grouping function.
2. `[5m]`, the **interval** (not resolution).
3. `.grouping()`.
4. **Agent Configuration** (standalone Unified Monitoring Agent on the hosts) + **Service Connector Hub** (Logging → Object Storage).
5. The **Notifications** side: the alarm's destination topic and whether the subscription is **confirmed (ACTIVE)**; a PENDING email subscription receives nothing.
6. No. Audit only records. Prevent with IAM (`read`/`inspect` for humans, `manage instances` only for automation) and compartment quotas; alert with Events → Notifications.

</details>

## Official references
- [Monitoring Query Language (MQL) reference](https://docs.oracle.com/en-us/iaas/Content/Monitoring/Reference/mql.htm)
- [Agent management: agent configurations](https://docs.oracle.com/en-us/iaas/Content/Logging/Concepts/agent_management.htm)
- [Connector Hub overview](https://docs.oracle.com/en-us/iaas/Content/connector-hub/overview.htm)
- [Audit overview](https://docs.oracle.com/en-us/iaas/Content/Audit/Concepts/auditoverview.htm)
