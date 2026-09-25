terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

# Same region as lab-mymagnet-stack: log groups, alarms and the archive
# bucket must live where the instances and LB emit their data.
provider "oci" {
  region = var.region
}

# IAM writes (dynamic group, policies) go to the tenancy's home region —
# same reason as lab-mymagnet-stack and lab-storage-stack (hard 403 otherwise).
provider "oci" {
  alias  = "home"
  region = "us-ashburn-1"
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

# =====================================================================
# Logging: log group + custom logs + Unified Monitoring Agent config
# =====================================================================
#
# SHAPE CAVEAT — read before applying. Both MyMagnet instances are
# VM.Standard.A1.Flex (Ampere Arm). Oracle's Oracle Cloud Agent plugin docs
# say: "On Arm-based OCI Ampere A1 Compute shapes, the Custom Logs
# Monitoring plugin is not supported." So enabling the plugin (the usual
# one-click path) does nothing on these instances.
#
# Workaround used here: install the *standalone* Unified Monitoring Agent
# by hand. Oracle's "Installing the Agent" page ships aarch64 builds for
# Ubuntu 22.04/24.04 (unified-monitoring-agent-ub-24-<ver>.aarch64.deb), and
# the agent-management matrix lists Ubuntu 24.04 as Arm-supported. The
# agent then pulls THIS agent configuration via the dynamic group below,
# exactly as the plugin would. Everything in this file is the same either
# way; only how the agent gets onto the host differs. Install steps are in
# LABS.md's lab-capstone-observability-stack entry.
#
# Alternatives if the manual agent doesn't work: switch the instances to
# VM.Standard.E5.Flex (x86, plugin supported — a boot-volume replacement,
# so it's a lab-mymagnet-stack change), or have the app call the Logging
# PutLogs API itself with its instance principal.

resource "oci_logging_log_group" "mymagnet" {
  compartment_id = var.compartment_ocid
  display_name   = "mymagnet-log-group"
  description    = "MyMagnet app and nginx logs from both backend instances"
}

# One custom log per source, because an agent configuration's destination
# is a single log object. Keeping app and nginx logs apart also lets the
# Connector Hub / search target one without the other.
#
# Paths: MAGNET_LOG_DIR=/opt/magnetlookup/data/logs is set in
# lab-mymagnet-stack/cloud-init.yaml.tftpl; nginx paths are Ubuntu's
# package defaults (setup.sh installs nginx from apt and doesn't override
# them — unverified on the live hosts, check with `ls /var/log/nginx`).
#
# Parsers: nginx's default access_log format is "combined", the same layout
# Apache's combined log uses, so APACHE2 parses it into fields. nginx's
# error log format isn't Apache's, so it and the app logs stay unparsed
# (NONE = one record per line).
locals {
  custom_logs = {
    app = {
      paths  = ["/opt/magnetlookup/data/logs/*"]
      parser = "NONE"
    }
    nginx-access = {
      paths  = ["/var/log/nginx/access.log"]
      parser = "APACHE2"
    }
    nginx-error = {
      paths  = ["/var/log/nginx/error.log"]
      parser = "NONE"
    }
  }
}

resource "oci_logging_log" "custom" {
  for_each = local.custom_logs

  display_name       = "mymagnet-${each.key}"
  log_group_id       = oci_logging_log_group.mymagnet.id
  log_type           = "CUSTOM"
  is_enabled         = true
  retention_duration = var.log_retention_days
}

# A separate dynamic group from lab-mymagnet-stack's mymagnet-instance-dyn-grp
# on purpose: that one is owned by another stack (and is currently stale —
# see CAPSTONE.md Phase 1), and its policy is scoped to the backup bucket.
# Keeping log-shipping identity here means this stack can be destroyed
# without touching the app's backup permissions.
resource "oci_identity_dynamic_group" "uma" {
  provider       = oci.home
  compartment_id = var.tenancy_ocid
  name           = "mymagnet-uma-dyn-grp"
  description    = "MyMagnet instances that run the Unified Monitoring Agent"
  matching_rule  = "ANY {instance.id = '${var.instance_1_id}', instance.id = '${var.instance_2_id}'}"
}

# Verified against Oracle's Logging docs: "use log-content" lets instances in
# the dynamic group download the agent configuration, send logs, and search
# logs. No other verb is needed for the agent itself.
resource "oci_identity_policy" "uma" {
  provider       = oci.home
  compartment_id = var.compartment_ocid
  name           = "mymagnet-uma-policy"
  description    = "Let the MyMagnet instances' Unified Monitoring Agent push custom logs"
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.uma.name} to use log-content in compartment id ${var.compartment_ocid}",
  ]
}

resource "oci_logging_unified_agent_configuration" "mymagnet" {
  for_each = local.custom_logs

  compartment_id = var.compartment_ocid
  display_name   = "mymagnet-${each.key}-agent-config"
  description    = "Tail ${join(", ", each.value.paths)} on both MyMagnet instances"
  is_enabled     = true

  service_configuration {
    configuration_type = "LOGGING"

    destination {
      log_object_id = oci_logging_log.custom[each.key].id
    }

    sources {
      name        = replace(each.key, "-", "_")
      source_type = "LOG_TAIL"
      paths       = each.value.paths

      parser {
        parser_type = each.value.parser
      }
    }
  }

  # Host group = the dynamic group. The agent on each host asks "which
  # configurations apply to me?" and gets these via the dynamic group match.
  group_association {
    group_list = [oci_identity_dynamic_group.uma.id]
  }

  # The agent can't fetch its config until the policy exists.
  depends_on = [oci_identity_policy.uma]
}

# =====================================================================
# Alarms -> Notifications
# =====================================================================

resource "oci_ons_notification_topic" "alarms" {
  compartment_id = var.compartment_ocid
  name           = "mymagnet-alarms"
  description    = "MyMagnet LB and instance alarms"
}

resource "oci_ons_subscription" "email" {
  compartment_id = var.compartment_ocid
  topic_id       = oci_ons_notification_topic.alarms.id
  protocol       = "EMAIL"
  endpoint       = var.alarm_email
}

# oci_lbaas metric names/dimensions checked against Oracle's "Load Balancer
# Metrics" reference: unhealthyBackendServers and httpResponses5xx, both at
# the backendSet component with a backendSetName dimension.
#
# Any unhealthy backend is worth an alert: with only two backends, one down
# is already half the capacity (and, with sticky sessions + per-node SQLite,
# half the users see a different library).
resource "oci_monitoring_alarm" "lb_unhealthy_backends" {
  compartment_id        = var.compartment_ocid
  metric_compartment_id = var.compartment_ocid
  display_name          = "mymagnet-lb-unhealthy-backends"
  is_enabled            = true
  namespace             = "oci_lbaas"
  query                 = "unhealthyBackendServers[1m]{resourceId = \"${var.load_balancer_id}\", backendSetName = \"${var.backend_set_name}\"}.max() > 0"
  severity              = "CRITICAL"
  # 5 minutes: rides out a single failed health-check interval (e.g. an
  # nginx reload) instead of paging on every blip.
  pending_duration = "PT5M"
  body             = "One or more MyMagnet backends are failing the LB health check (GET / on port 80)."
  destinations     = [oci_ons_notification_topic.alarms.id]
  message_format   = "ONS_OPTIMIZED"
}

# Backend-set scoped, i.e. 5xx returned by nginx/the app. LB-generated
# 502/504s when a backend is down are already covered by the alarm above.
resource "oci_monitoring_alarm" "lb_5xx" {
  compartment_id        = var.compartment_ocid
  metric_compartment_id = var.compartment_ocid
  display_name          = "mymagnet-lb-5xx"
  is_enabled            = true
  namespace             = "oci_lbaas"
  query                 = "httpResponses5xx[5m]{resourceId = \"${var.load_balancer_id}\", backendSetName = \"${var.backend_set_name}\"}.sum() > ${var.http_5xx_threshold}"
  severity              = "WARNING"
  pending_duration      = "PT5M"
  body                  = "MyMagnet backends returned more than ${var.http_5xx_threshold} HTTP 5xx responses in 5 minutes."
  destinations          = [oci_ons_notification_topic.alarms.id]
  message_format        = "ONS_OPTIMIZED"
}

# CpuUtilization comes from the Compute Instance Monitoring plugin, which
# (unlike Custom Logs Monitoring) IS supported on Ampere A1, and is enabled
# on both instances (agent_config.is_monitoring_disabled = false in
# lab-mymagnet-stack's state). One alarm for both instances: the =~ filter
# plus per-dimension notifications sends a separate message per instance.
resource "oci_monitoring_alarm" "instance_cpu" {
  compartment_id                                = var.compartment_ocid
  metric_compartment_id                         = var.compartment_ocid
  display_name                                  = "mymagnet-instance-cpu"
  is_enabled                                    = true
  namespace                                     = "oci_computeagent"
  query                                         = "CpuUtilization[5m]{resourceId =~ \"${var.instance_1_id}|${var.instance_2_id}\"}.mean() > ${var.cpu_alarm_threshold_percent}"
  severity                                      = "WARNING"
  pending_duration                              = "PT10M"
  is_notifications_per_metric_dimension_enabled = true
  body                                          = "A MyMagnet instance has averaged over ${var.cpu_alarm_threshold_percent}% CPU for 10 minutes (1 OCPU A1 — the daily scrape job is the usual suspect)."
  destinations                                  = [oci_ons_notification_topic.alarms.id]
  message_format                                = "ONS_OPTIMIZED"
}

# =====================================================================
# Optional: Connector Hub archive of the log group to Object Storage
# =====================================================================
# Logging keeps custom logs for log_retention_days at most; Connector Hub
# copies them to a bucket for cheap long-term retention (the "archive logs
# to Object Storage" use case from Note 8).

resource "oci_objectstorage_bucket" "log_archive" {
  count          = var.enable_log_archive ? 1 : 0
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "mymagnet-log-archive"
  access_type    = "NoPublicAccess"
}

# Object Lifecycle Management acts as the Object Storage *service*, so the
# service itself needs permission. Oracle's docs: create it in the tenancy
# root compartment, once per region that uses lifecycle rules. Without it,
# the lifecycle policy below fails to create.
resource "oci_identity_policy" "objectstorage_lifecycle" {
  count          = var.enable_log_archive ? 1 : 0
  provider       = oci.home
  compartment_id = var.tenancy_ocid
  name           = "mymagnet-objectstorage-lifecycle-${var.region}"
  description    = "Let Object Storage in ${var.region} run lifecycle rules on the MyMagnet log archive"
  statements = [
    "Allow service objectstorage-${var.region} to manage object-family in compartment id ${var.compartment_ocid}",
  ]
}

resource "oci_objectstorage_object_lifecycle_policy" "log_archive" {
  count     = var.enable_log_archive ? 1 : 0
  namespace = data.oci_objectstorage_namespace.ns.namespace
  bucket    = oci_objectstorage_bucket.log_archive[0].name

  rules {
    name        = "archive-old-logs"
    action      = "ARCHIVE"
    is_enabled  = true
    target      = "objects"
    time_amount = var.archive_after_days
    time_unit   = "DAYS"
  }

  rules {
    name        = "delete-expired-logs"
    action      = "DELETE"
    is_enabled  = true
    target      = "objects"
    time_amount = var.delete_after_days
    time_unit   = "DAYS"
  }

  depends_on = [oci_identity_policy.objectstorage_lifecycle]
}

# Connector Hub writes as its own principal. Policy text is Oracle's
# documented Object Storage target template. A Logging *source* needs no
# extra policy.
resource "oci_identity_policy" "sch_to_bucket" {
  count          = var.enable_log_archive ? 1 : 0
  provider       = oci.home
  compartment_id = var.compartment_ocid
  name           = "mymagnet-sch-log-archive"
  description    = "Let the MyMagnet Connector Hub write to the log archive bucket"
  statements = [
    "Allow any-user to manage objects in compartment id ${var.compartment_ocid} where all {request.principal.type='serviceconnector', target.bucket.name='${oci_objectstorage_bucket.log_archive[0].name}', request.principal.compartment.id='${var.compartment_ocid}'}",
  ]
}

resource "oci_sch_service_connector" "log_archive" {
  count          = var.enable_log_archive && var.enable_log_connector ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "mymagnet-log-archive"
  description    = "Archive the MyMagnet log group to Object Storage"

  source {
    kind = "logging"
    # Whole log group, so a log added to it later is archived without
    # editing the connector.
    log_sources {
      compartment_id = var.compartment_ocid
      log_group_id   = oci_logging_log_group.mymagnet.id
    }
  }

  target {
    kind      = "objectStorage"
    bucket    = oci_objectstorage_bucket.log_archive[0].name
    namespace = data.oci_objectstorage_namespace.ns.namespace
    # 7 minutes is Oracle's documented limit; set explicitly so it's clear a
    # low-traffic app rolls on time (a new .gz every 7 min), not on the
    # 100 MB size limit it may take days to reach.
    batch_rollover_time_in_ms = 420000
  }

  depends_on = [oci_identity_policy.sch_to_bucket, oci_logging_log.custom]
}
