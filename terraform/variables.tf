variable "NEW_RELIC_ACCOUNT_ID" {
  type = string
}

variable "NEW_RELIC_API_KEY" {
  type      = string
  sensitive = true
}

variable "NEW_RELIC_REGION" {
  type    = string
  default = "US"
}