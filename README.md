# New Relic "Synthetics-as-Code" Framework
This repository provides a standardized, multi-account automation framework for managing New Relic Synthetics monitors using Terraform, GitHub Actions, and YAML.

## 🚀 Overview
This solution allows engineering teams to manage their own Synthetic monitors by simply editing a YAML file. The underlying Terraform modules handle the complexity of provider configurations, tagging, and modern runtime requirements.

### Key Features
- Multi-Account Support: Deploy monitors to different New Relic accounts from a single repo.
- Standardized Tagging: Automatically applies metadata (Team, Environment, etc.) for better filtering in New Relic.
- GitOps Workflow: Changes are previewed in Pull Requests (terraform plan) and applied automatically on merge.
- Modern Runtimes: Out-of-the-box support for the latest New Relic Chrome and Node runtimes.

## 📂 Repository Structure
Plaintext
├── .github/workflows/       # GitHub Action pipelines
├── teams/                   # YAML definitions (One per team)
│   ├── team-alpha.yml
│   └── team-beta.yml
├── terraform/
│   ├── main.tf              # Module orchestrator
│   ├── providers.tf         # Multi-account connection hub
│   ├── backend.tf           # S3 State configuration
│   └── modules/
│       └── monitor_set/     # Reusable logic for all monitors
└── README.md
🛠 How to Add a New Monitor
To add a monitor, navigate to the teams/ folder and update your team's YAML file.

Example: teams/team-alpha.yml
YAML
monitors:
  - name: "Alpha-Homepage-Ping"
    type: "SIMPLE"        # Options: SIMPLE, BROWSER
    uri: "https://example.com"
    period: "EVERY_MINUTE"
    locations: ["US_EAST_1", "AWS_US_WEST_2"]
    tags: 
      team: "alpha"
      env: "production"

  - name: "Alpha-SSL-Check"
    type: "CERT_CHECK"
    domain: "example.com"
    period: "EVERY_DAY"
    locations: ["US_EAST_1"]
    tags: 
      team: "alpha"
🏗 Setup & Onboarding a New Team
To onboard a new team/account to this framework:

Create a YAML file in /teams (e.g., team-gamma.yml).

Add Provider Alias in terraform/providers.tf:

Terraform
provider "newrelic" {
  alias      = "gamma"
  account_id = var.GAMMA_ACCOUNT_ID
  api_key    = var.GAMMA_API_KEY
}
Call the Module in terraform/main.tf:

Terraform
module "team_gamma" {
  source    = "./modules/monitor_set"
  yaml_file = "../teams/team-gamma.yml"
  providers = { newrelic = newrelic.gamma }
}
Update GitHub Secrets with the new API keys and Account IDs.

🔐 Security & State
State Management: This project uses an S3 bucket for Terraform State to ensure consistency and prevent resource duplication.

Locking: Native S3 locking is enabled to prevent concurrent deployment conflicts.

Secrets: No API keys are stored in code. All credentials must be stored in GitHub Actions Secrets.

🚦 Deployment Pipeline
Pull Request: Triggers a terraform plan. Review the output in the GitHub Action log to see what will be created/changed/deleted.

Merge to Main: Triggers terraform apply. This live-deploys the monitors to the specified New Relic accounts.