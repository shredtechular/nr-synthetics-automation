terraform {
  backend "s3" {
    bucket = "my-new-relic-synthetics-states" # Your unique S3 bucket name
    key    = "synthetics/terraform.tfstate"
    region = "us-east-1"
    # New for 2026: S3 now supports native locking without DynamoDB!
    use_lockfile = true
    encrypt      = true
  }
}