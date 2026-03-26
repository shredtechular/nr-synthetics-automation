# --- TEAM Andrew ---
module "team_andrew" {
  source    = "./modules/monitor_set"
  yaml_file = "../teams/team-andrew.yml"
  providers = {
    newrelic = newrelic.andrew
  }
}

# --- TEAM WebSystems ---
module "team_websystems" {
  source    = "./modules/monitor_set"
  yaml_file = "../teams/team-websystems.yml"
  providers = {
    newrelic = newrelic
  }
}

# --- TEAM GAMMA ---
# Just keep repeating this pattern!