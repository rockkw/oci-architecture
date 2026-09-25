variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }

variable "region" {
  type    = string
  default = "us-phoenix-1"
}

# Taken from lab-mymagnet-stack's outputs (`terraform output` there), not
# terraform_remote_state, matching every other stack in this repo.
variable "instance_1_id" { type = string }
variable "instance_2_id" { type = string }
variable "load_balancer_id" { type = string }

# Must match lab-mymagnet-stack's oci_load_balancer_backend_set name. Used to
# scope the 5xx alarm to backend-generated errors (see main.tf).
variable "backend_set_name" {
  type    = string
  default = "mymagnet-backend-set"
}

# No default on purpose: a Notifications email subscription sends a
# confirmation mail, and alarms go nowhere until someone clicks it. A wrong
# default would silently route alerts to the wrong inbox.
variable "alarm_email" {
  type        = string
  description = "Email address subscribed to the alarm topic. OCI sends a confirmation link; alarms are not delivered until it's clicked."
}

variable "cpu_alarm_threshold_percent" {
  type    = number
  default = 80
}

# Backend-generated 5xx count per 5-minute window before the alarm fires.
# Not 0: one transient 502 during a deploy shouldn't page anyone.
variable "http_5xx_threshold" {
  type    = number
  default = 5
}

# Custom log retention in Logging itself. 30 days is the Logging default;
# the archive bucket below is the long-term copy.
variable "log_retention_days" {
  type    = number
  default = 30
}

# --- Optional Connector Hub archive (log group -> Object Storage) ---
variable "enable_log_archive" {
  type    = bool
  default = true
}

# Connector Hub rejects a log source that has no data yet ("No log sources
# found to be read"). The custom logs stay empty until the Unified Monitoring
# Agent is installed by hand on the A1 instances, so turn this on after that.
variable "enable_log_connector" {
  type    = bool
  default = false
}

# Objects move to Archive tier after this many days, then are deleted.
# Archive storage has a 90-day minimum retention charge, so delete_after
# should be at least archive_after + 90 or you pay for days you didn't keep.
variable "archive_after_days" {
  type    = number
  default = 30
}

variable "delete_after_days" {
  type    = number
  default = 365
}
