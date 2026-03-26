# --- TEAM ALPHA (Account 123) ---
module "team_alpha" {
  source    = "./modules/monitor_set"
  yaml_file = "../teams/team-alpha.yml"
  providers = {
    newrelic = newrelic.alpha 
  }
}

# --- TEAM BETA (Account 456) ---
module "team_beta" {
  source    = "./modules/monitor_set"
  yaml_file = "../teams/team-beta.yml"
  providers = {
    newrelic = newrelic.beta
  }
}

# --- TEAM GAMMA (Account 789) ---
# Just keep repeating this pattern!