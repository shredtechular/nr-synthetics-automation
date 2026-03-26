# Default provider (Required for initialization)
provider "newrelic" {
  alias      = "websystems"
  account_id = var.NEW_RELIC_ACCOUNT_ID
  api_key    = var.NEW_RELIC_API_KEY
  region     = var.NEW_RELIC_REGION
}

provider "newrelic" {
  alias      = "andrew"
  account_id = var.ANDREW_ACCOUNT_ID
  api_key    = var.NEW_RELIC_API_KEY
  region     = var.NEW_RELIC_REGION
}