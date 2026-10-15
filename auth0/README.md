# Auth0 tenant setup (shared by every cloud demo)

One Terraform root for everything on the Auth0 side. The cloud roots (`../aws/tf`, `../gcp/tf`, `../azure/tf`) do not use the Auth0 provider; they read the issuer, client IDs and API audience from this root's outputs (`terraform_remote_state`, local state). **Apply this root first.**

| Resource                                 | File        | Purpose                                                                  |
|------------------------------------------|-------------|--------------------------------------------------------------------------|
| Custom domain (+ verification)           | `shared.tf` | Token issuer for all clouds (tenant-wide, optional, two stages)          |
| Database connection `users`, test user   | `shared.tf` | Sign-up disabled; only Terraform-created users can log in                |
| "Other" API                              | `shared.tf` | Negative test: its tokens must be rejected by every cloud trust          |
| API, SPA client, CLI client              | `aws.tf`    | AWS demo (`https://aws.wif`)                                              |
| API, SPA client, CLI client              | `gcp.tf`    | GCP demo (`https://gcp.wif`)                                              |
| API, SPA client, CLI client              | `azure.tf`  | Azure demo (`api://AzureADTokenExchange`, the audience Entra expects)     |

## Setup

1. **Auth0 M2M application for Terraform.** In the Auth0 dashboard, create a Machine-to-Machine application and authorize it for the *Auth0 Management API* with these scopes:
   `read:clients create:clients update:clients delete:clients`,
   `read:resource_servers create:resource_servers update:resource_servers delete:resource_servers`,
   `read:connections create:connections update:connections delete:connections`,
   `read:users create:users update:users delete:users`,
   `read:custom_domains create:custom_domains update:custom_domains delete:custom_domains` (only for the custom domain).
2. Terraform >= 1.9 and `make`.

```bash
cd auth0
cp terraform.auth.tfvars.example terraform.auth.tfvars   # gitignored; fill in your values
make plan
make apply
make output
```

`make help` lists all targets.

### Custom domain (optional, two stages)

An Auth0-managed custom domain, e.g. `id.wif.abbaspour.net`. Tokens issued through it carry `iss = https://id.wif.abbaspour.net/`, so the cloud trusts and the apps use that issuer once it is active (the `auth0_issuer_domain` output). Terraform's own Management API calls keep using `auth0_domain`. A tenant normally has one custom domain, which is why it lives here.

1. Set `auth0_custom_domain = "id.wif.abbaspour.net"` in `terraform.auth.tfvars`, then `make plan && make apply`.
2. `make output`: `custom_domain_dns_records` lists the record to create (type, host, target). Add it in your DNS zone.
3. Set `auth0_custom_domain_verified = true`, then `make plan && make apply`.
4. Re-apply the cloud roots (`aws/tf`, `gcp/tf`, `azure/tf`) so their trust configuration moves to the new issuer, and regenerate the SPA config with each cloud's `scripts/spa-env.sh`. Access tokens with the old `iss` stop working.

### SPA hosts

`aws_spa_domain` / `gcp_spa_domain` / `azure_spa_domain` add the deployed Cloudflare Worker host to each SPA client's callback, logout and web-origin URLs (alongside `*_spa_origins`, default `http://localhost:5173`). They must match the route in `aws/spa/wrangler.jsonc` / `gcp/spa/wrangler.jsonc` / `azure/spa/wrangler.jsonc`. The cloud roots read the same list from this root for bucket CORS.
