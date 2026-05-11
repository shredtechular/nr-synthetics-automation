variable "yaml_file" { type = string }

locals {
  team_data = yamldecode(file(var.yaml_file))
  monitors  = local.team_data.monitors
}

# Logic for SIMPLE & BROWSER MONITORS
resource "newrelic_synthetics_monitor" "monitor" {
  for_each = { 
    for m in local.team_data.monitors : m.name => m 
    if !contains(["CERT_CHECK", "SCRIPTED_API"], m.type)
  }

  name                 = each.value.name
  type                 = each.value.type
  uri                  = lookup(each.value, "uri", null)
  period               = each.value.period
  status               = "ENABLED"
  runtime_type_version = "100"
  runtime_type         = "CHROME_BROWSER"
  locations_public     = lookup(each.value, "locations", ["US_EAST_1"])
}

# Logic for SSL/CERT_CHECK
resource "newrelic_synthetics_cert_check_monitor" "ssl_monitor" {
  for_each = { 
    for m in local.team_data.monitors : m.name => m 
    if m.type == "CERT_CHECK" 
  }

  name                   = each.value.name
  domain                 = each.value.domain
  period                 = each.value.period
  status                 = "ENABLED"
  certificate_expiration = 30 # Default to 30 days
  locations_public       = lookup(each.value, "locations", ["US_EAST_1"])
  runtime_type           = "NODE_API"
  runtime_type_version   = "16.10"
}

# Logic for SCRIPTED_API MONITORS
resource "newrelic_synthetics_script_monitor" "scripted_api_monitor" {
  for_each = {
    for m in local.team_data.monitors : m.name => m
    if m.type == "SCRIPTED_API"
  }

  name   = each.value.name
  type   = "SCRIPT_API"
  period = each.value.period
  status = "ENABLED"

  runtime_type         = "NODE_API"
  runtime_type_version = "16.10"

  locations_public = lookup(each.value, "locations", ["US_EAST_1"])

  script = templatefile("${path.module}/api_monitor_template.js.tftpl", {
    api_url        = each.value.api_url
    http_method    = lookup(each.value, "http_method", "GET")
    custom_headers = jsonencode(lookup(each.value, "custom_headers", {}))
    payload         = lookup(each.value, "payload", null) != null ? jsonencode(lookup(each.value, "payload", null)) : "null"
    expected_status = lookup(each.value, "expected_status", 200)
    timeout_ms      = lookup(each.value, "timeout_seconds", 45) * 1000
  })
}

# Logic for TAGS
resource "newrelic_entity_tags" "tags" {
  for_each = { for m in local.team_data.monitors : m.name => m if can(m.tags) }

  # This dynamic lookup finds the GUID regardless of which resource created it
  guid = (
    contains(["SIMPLE", "BROWSER"], each.value.type) ?
    newrelic_synthetics_monitor.monitor[each.key].id :
    each.value.type == "SCRIPTED_API" ?
    newrelic_synthetics_script_monitor.scripted_api_monitor[each.key].id :
    newrelic_synthetics_cert_check_monitor.ssl_monitor[each.key].id
  )

  dynamic "tag" {
    for_each = each.value.tags
    content {
      key    = tag.key
      values = [tag.value]
    }
  }
}

# -----------------------------------------------------------------------
# ALERTS
# -----------------------------------------------------------------------

locals {
  alerts_enabled = can(local.team_data.alerts)
  email_enabled  = can(local.team_data.alerts.notification_emails)

  team_name_from_path = replace(basename(var.yaml_file), ".yml", "")

  policy_name = (
    local.alerts_enabled && can(local.team_data.alerts.policy_name)
    ? local.team_data.alerts.policy_name
    : "${local.team_name_from_path} Alerts"
  )

  alert_conditions = local.alerts_enabled ? {
    for c in local.team_data.alerts.conditions : c.name => c
  } : {}
}

# Alert Policy — created when an alerts: block exists in the team YAML
resource "newrelic_alert_policy" "alert_policy" {
  count = local.alerts_enabled ? 1 : 0

  name                = local.policy_name
  incident_preference = "PER_POLICY"
}

# NRQL Alert Conditions — one per entry in alerts.conditions
# Supports any NRQL data source: Synthetics, APM, Browser, Infrastructure, Logs
resource "newrelic_nrql_alert_condition" "condition" {
  for_each  = local.alert_conditions
  policy_id = newrelic_alert_policy.alert_policy[0].id

  name    = each.value.name
  type    = "static"
  enabled = true

  nrql {
    query = each.value.nrql
  }

  aggregation_window = lookup(each.value, "aggregation_window", 60)
  aggregation_method = lookup(each.value, "aggregation_method", "event_flow")
  aggregation_delay  = lookup(each.value, "aggregation_delay", 120)

  critical {
    operator              = each.value.threshold_operator
    threshold             = each.value.critical_threshold
    threshold_duration    = lookup(each.value, "threshold_duration", 60)
    threshold_occurrences = lookup(each.value, "threshold_occurrences", "at_least_once")
  }

  fill_option                    = lookup(each.value, "fill_option", "none")
  expiration_duration            = 300
  open_violation_on_expiration   = false
  close_violations_on_expiration = true
}

# Email Notification Destination — created when alerts.notification_email is set
resource "newrelic_notification_destination" "email" {
  count = local.email_enabled ? 1 : 0

  name = "${local.policy_name} - Email"
  type = "EMAIL"

  property {
    key   = "email"
    value = join(",", local.team_data.alerts.notification_emails)
  }
}

# Notification Channel (message template)
resource "newrelic_notification_channel" "email_channel" {
  count          = local.email_enabled ? 1 : 0
  name           = "${local.policy_name} - Email Channel"
  type           = "EMAIL"
  product        = "IINT"
  destination_id = newrelic_notification_destination.email[0].id

  property {
    key   = "subject"
    value = "New Relic Alert: {{ issueTitle }}"
  }
}

# Workflow — routes issues from this policy to the email destination
resource "newrelic_workflow" "email_workflow" {
  count   = local.email_enabled ? 1 : 0
  name    = "${local.policy_name} - Workflow"
  enabled = true

  muting_rules_handling = "DONT_NOTIFY_FULLY_MUTED_ISSUES"

  issues_filter {
    name = "Policy Filter"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [tostring(newrelic_alert_policy.alert_policy[0].id)]
    }
  }

  destination {
    channel_id            = newrelic_notification_channel.email_channel[0].id
    notification_triggers = ["ACTIVATED", "ACKNOWLEDGED", "CLOSED"]
  }
}