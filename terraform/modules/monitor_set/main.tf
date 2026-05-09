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
    payload        = lookup(each.value, "payload", null) != null ? jsonencode(lookup(each.value, "payload", null)) : "null"
    expected_status = lookup(each.value, "expected_status", 200)
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