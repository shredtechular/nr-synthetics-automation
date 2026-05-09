# New Relic Synthetics-as-Code Framework

A standardized, multi-account automation framework for managing New Relic Synthetics monitors using Terraform, GitHub Actions, and YAML.

## Overview

Teams manage their own monitors by editing a single YAML file. The underlying Terraform modules handle provider configuration, script templating, tagging, and runtime requirements automatically.

**Key features:**
- **Multi-account support** — Deploy monitors to different New Relic accounts from a single repo
- **Four monitor types** — Ping, Simple Browser, SSL Cert, and Scripted API
- **Standardized tagging** — Automatically applies metadata (team, environment, etc.) for filtering in New Relic
- **GitOps workflow** — Changes are previewed in Pull Requests (`terraform plan`) and applied automatically on merge to `main`
- **Modern runtimes** — Chrome 100 for browser monitors, Node 16.10 for API and cert checks

## Repository Structure

```
├── .github/workflows/           # GitHub Actions CI/CD pipeline
├── teams/                       # YAML monitor definitions (one file per team)
│   ├── team-alpha.yml
│   └── team-beta.yml
├── terraform/
│   ├── main.tf                  # Module orchestrator (one block per team)
│   ├── providers.tf             # Multi-account New Relic provider config
│   ├── variables.tf             # Input variables
│   ├── backend.tf               # S3 state configuration
│   └── modules/
│       └── monitor_set/
│           ├── main.tf                          # Core resource logic
│           └── api_monitor_template.js.tftpl    # Scripted API monitor template
└── api_monitor_template_clean.js    # Human-readable reference for the API template
```

## Adding or Changing a Monitor

Navigate to `teams/` and edit your team's YAML file. Each entry in the `monitors` list creates one monitor in New Relic.

### Monitor Types

| Type | New Relic Resource | Use Case |
|---|---|---|
| `SIMPLE` | Synthetics Monitor | Ping / HTTP availability check |
| `BROWSER` | Synthetics Monitor | Simple browser page load check |
| `CERT_CHECK` | Cert Check Monitor | SSL certificate expiration check |
| `SCRIPTED_API` | Script Monitor | Custom HTTP API validation with configurable method, headers, and payload |

### Common Fields

| Field | Required | Description |
|---|---|---|
| `name` | Yes | Unique monitor name (shown in New Relic UI) |
| `type` | Yes | One of: `SIMPLE`, `BROWSER`, `CERT_CHECK`, `SCRIPTED_API` |
| `period` | Yes | `EVERY_MINUTE`, `EVERY_15_MINUTES`, `EVERY_HOUR`, `EVERY_DAY` |
| `locations` | No | Array of public location strings. Defaults to `["US_EAST_1"]` |
| `tags` | No | Key-value map of metadata tags applied to the monitor in New Relic |

### YAML Examples

**Ping monitor:**
```yaml
monitors:
  - name: "Alpha-Homepage-Ping"
    type: "SIMPLE"
    uri: "https://example.com"
    period: "EVERY_15_MINUTES"
    locations: ["US_EAST_1", "AWS_US_WEST_2"]
    tags:
      team: "alpha"
      env: "production"
      responsible-team: "alpha-sre"
```

**Simple Browser monitor:**
```yaml
  - name: "Alpha-Login-Browser"
    type: "BROWSER"
    uri: "https://example.com/login"
    period: "EVERY_15_MINUTES"
    locations: ["US_WEST_1"]
    tags:
      team: "alpha"
      env: "production"
```

**SSL Cert check:**
```yaml
  - name: "Alpha-SSL-Check"
    type: "CERT_CHECK"
    domain: "example.com"
    period: "EVERY_DAY"
    locations: ["US_EAST_1"]
    tags:
      team: "alpha"
      env: "production"
```

**Scripted API monitor (minimal — GET with all defaults):**
```yaml
  - name: "Alpha-HealthCheck-API"
    type: "SCRIPTED_API"
    api_url: "https://api.example.com/health"
    period: "EVERY_15_MINUTES"
    locations: ["US_EAST_1"]
    tags:
      team: "alpha"
      env: "production"
```

**Scripted API monitor (POST with headers and payload):**
```yaml
  - name: "Alpha-CreateOrder-API"
    type: "SCRIPTED_API"
    api_url: "https://api.example.com/v1/orders"
    http_method: "POST"
    custom_headers:
      Content-Type: "application/json"
      Authorization: "Bearer test-token"
    payload:
      customerId: "test-123"
      productId: "widget-456"
    expected_status: 201
    period: "EVERY_15_MINUTES"
    locations: ["US_EAST_1"]
    tags:
      team: "alpha"
      env: "production"
```

#### Scripted API Fields

| Field | Required | Default | Notes |
|---|---|---|---|
| `api_url` | Yes | — | Full endpoint URL including query string |
| `http_method` | No | `GET` | `GET`, `POST`, `PUT`, `PATCH`, `DELETE` |
| `custom_headers` | No | `{}` | Key-value map of request headers |
| `payload` | No | `null` | Request body for POST/PUT/PATCH. Omit for GET |
| `expected_status` | No | `200` | HTTP response code to assert against |

The script logic (transport error handling, status validation, body validation) is shared across all Scripted API monitors via `api_monitor_template.js.tftpl`. Only the five config values above vary per monitor.

## Onboarding a New Team

1. **Create a YAML file** in `teams/` (e.g., `teams/team-gamma.yml`)

2. **Add a provider alias** in `terraform/providers.tf`:
   ```hcl
   provider "newrelic" {
     alias      = "gamma"
     account_id = var.GAMMA_ACCOUNT_ID
     api_key    = var.GAMMA_API_KEY
   }
   ```

3. **Add input variables** in `terraform/variables.tf`:
   ```hcl
   variable "GAMMA_ACCOUNT_ID" { type = string }
   variable "GAMMA_API_KEY"    { type = string, sensitive = true }
   ```

4. **Call the module** in `terraform/main.tf`:
   ```hcl
   module "team_gamma" {
     source    = "./modules/monitor_set"
     yaml_file = "../teams/team-gamma.yml"
     providers = { newrelic = newrelic.gamma }
   }
   ```

5. **Add GitHub Secrets** for `GAMMA_ACCOUNT_ID` and `GAMMA_API_KEY` in the repository settings

## Deployment Pipeline

| Event | Action |
|---|---|
| Pull Request to `main` | `terraform plan` — output appears in the GitHub Actions log |
| Merge to `main` | `terraform apply` — monitors are created/updated/deleted in New Relic |

The pipeline triggers only when files under `teams/` or `terraform/` are changed.

## Security & State

- **State** — Stored in S3 with native locking enabled to prevent concurrent deployment conflicts
- **Secrets** — No API keys are stored in code; all credentials are stored as GitHub Actions Secrets
- **Encryption** — S3 state bucket has server-side encryption enabled
