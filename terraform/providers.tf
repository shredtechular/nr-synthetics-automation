terraform {
  required_providers {
    newrelic = {
      source = "newrelic/newrelic"
    }
  }
}

# Now define your aliases
provider "newrelic" {
  alias      = "andrew"
  account_id = var.ANDREW_ACCOUNT_ID
  api_key    = var.NEW_RELIC_API_KEY
  region     = var.NEW_RELIC_REGION
}

provider "newrelic" {
  alias      = "websystems"
  account_id = var.NEW_RELIC_ACCOUNT_ID
  api_key    = var.NEW_RELIC_API_KEY
  region     = var.NEW_RELIC_REGION
}

# Pro-Tip: Add a default provider with no alias 
# to satisfy the "newrelic = newrelic" warning
provider "newrelic" {
  account_id = var.NEW_RELIC_ACCOUNT_ID # Or any default account
  api_key    = var.NEW_RELIC_API_KEY
  region     = var.NEW_RELIC_REGION
}