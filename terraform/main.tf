locals {
  # Load all YAML files from the teams folder
  team_files = fileset("../teams", "*.yml")
  raw_data   = [for f in local.team_files : yamldecode(file("../teams/${f}"))]

  # Flatten into a single list of monitors
  all_monitors = flatten([for d in local.raw_data : d.monitors])
}

# --- 1. SIMPLE & BROWSER MONITORS ---
resource "newrelic_synthetics_monitor" "monitor" {
  # Only pick monitors where type is SIMPLE or BROWSER
  for_each = {
    for m in local.all_monitors : m.name => m
    if m.type == "SIMPLE" || m.type == "BROWSER"
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

# --- 2. SSL (CERT) CHECK MONITORS ---
resource "newrelic_synthetics_cert_check_monitor" "ssl_monitor" {
  # Only pick monitors where type is CERT_CHECK
  for_each = {
    for m in local.all_monitors : m.name => m
    if m.type == "CERT_CHECK"
  }

  name                   = each.value.name
  domain                 = each.value.domain
  period                 = each.value.period
  status                 = "ENABLED"
  certificate_expiration = 30 # Default to 30 days
  locations_public       = lookup(each.value, "locations", ["US_EAST_1"])
}

# --- 3. UPDATED TAGGING LOGIC ---
# We now need to apply tags to BOTH types of resources
resource "newrelic_entity_tags" "all_tags" {
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