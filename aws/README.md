# AWS: Auth0 → IAM `AssumeRoleWithWebIdentity`

An Auth0 access token is exchanged with AWS STS for temporary credentials that only reach `users/<sub>/` in an S3 bucket.

## Phase 1: Terraform foundation (`tf/`)

Creates:

- **Auth0:** an API (the token audience), a SPA application, enablement of the SPA on the database connection, and a test user.
- **AWS:** an IAM OIDC provider for the tenant, a web-identity role, and an S3 bucket (public access blocked, CORS for the SPA origin).

### Prerequisites

1. **Auth0 M2M application for Terraform.** In the Auth0 dashboard, create a Machine-to-Machine application and authorize it for the *Auth0 Management API* with these scopes:
   `read:clients create:clients update:clients delete:clients`,
   `read:resource_servers create:resource_servers update:resource_servers delete:resource_servers`,
   `read:connections update:connections`,
   `read:users create:users update:users delete:users`.
2. **AWS CLI profile** with permission to manage IAM, STS and S3 in the target account.
3. Terraform >= 1.6 and `make`.

### Configure

```sh
cd aws/tf
cp terraform.auth.tfvars.example terraform.auth.tfvars   # gitignored; fill in tenant, M2M credentials, AWS profile, test user
```

### Run

```sh
make plan      # init + terraform plan -> saved plan file
make apply     # applies exactly that saved plan
make output    # role ARN, bucket, audience, client ID, ...
make destroy   # tear everything down (asks for confirmation)
```

`make help` lists all targets (`init`, `fmt`, `validate` too).

## How the trust works

- Auth0 access tokens carry `azp` = the requesting client's ID. AWS maps `azp` (when present) to the `aud` condition key, so the IAM provider's `client_id_list` and the role's trust condition use the **SPA client ID**, not the API audience.
- The token's original `aud` is exposed as `oaud`. It is available in trust policies only, and is not checked yet. See `CLAUDE.md` for the open hardening item.
- `sub` is available in the role session, so the permissions policy restricts each user to `users/<sub>/*` with the policy variable `${<issuer-host>/:sub}`.

## Phase 2 and 3

Verification scripts (`scripts/`) and the demo SPA (`spa/`) are not built yet.
