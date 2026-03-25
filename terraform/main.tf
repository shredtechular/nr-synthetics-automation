locals {
  # Load all YAML files from the teams folder
  team_files = fileset("../teams", "*.yml")
  raw_data   = [for f in local.team_files : yamldecode(file("../teams/${f}"))]

  # Flatten into a single list of monitors
  all_monitors = flatten([for d in local.raw_data : d.monitors])
}

# 1. Create the Monitors (Existing Logic)
resource "newrelic_synthetics_monitor" "monitor" {
  for_each = { for m in local.all_monitors : m.name => m }

  name                 = each.value.name
  type                 = each.value.type
  uri                  = lookup(each.value, "uri", null)
  period               = each.value.period
  status               = "ENABLED"
  runtime_type_version = "100"
  runtime_type         = "CHROME_BROWSER"
  locations_public     = lookup(each.value, "locations", ["US_EAST_1"])
}

# 2. Apply the Tags (New Logic)
resource "newrelic_entity_tags" "monitor_tags" {
  for_each = { for m in local.all_monitors : m.name => m if can(m.tags) }

  # Get the GUID from the monitor we just created
  guid = newrelic_synthetics_monitor.monitor[each.key].id

  # Loop through the tags map in YAML
  dynamic "tag" {
    for_each = each.value.tags
    content {
      key    = tag.key
      values = [tag.value]
    }
  }
}