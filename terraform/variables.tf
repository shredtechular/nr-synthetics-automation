# Global & Default Variables
variable "NEW_RELIC_REGION" {
  type    = string
  default = "US"
}

variable "NEW_RELIC_ACCOUNT_ID" {
  type = string
}

variable "NEW_RELIC_API_KEY" {
  type      = string
  sensitive = true
}

# Team Andrew
variable "ANDREW_ACCOUNT_ID" { 
  type = string 
}
variable "ANDREW_API_KEY"    { 
  type = string 
  sensitive = true 
}