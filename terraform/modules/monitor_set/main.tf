variable "yaml_file" { type = string }

locals {
  team_data = yamldecode(file(var.yaml_file))
  monitors  = local.team_data.monitors
}

# Logic for SIMPLE & BROWSER MONITORS
resource "newrelic_synthetics_monitor" "monitor" {
  for_each = { 
    for m in local.team_data.monitors : m.name => m 
    if m.type != "CERT_CHECK" 
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

# Logic for TAGS
resource "newrelic_entity_tags" "tags" {
  for_each = { for m in local.all_monitors : m.name => m if can(m.tags) }

  # This dynamic lookup finds the GUID regardless of which resource created it
  guid = (
    contains(["SIMPLE", "BROWSER"], each.value.type) ?
    newrelic_synthetics_monitor.monitor[each.key].id :
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