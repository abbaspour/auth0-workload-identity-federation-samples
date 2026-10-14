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

## Phase 2: verify federation with curl and the AWS CLI (`scripts/`)

Requires the Phase 1 apply, which includes the `cli` device-flow client. The scripts read their settings from `terraform output`.

```sh
cd aws/scripts

# 1. Log in (device flow): prints a URL and code; sign in as the test user.
#    -v prints the token's claims (iss, aud, azp, sub) to stderr.
./device-token.sh -v > .token

# 2. Exchange the Auth0 access token for temporary AWS credentials,
#    using curl against the STS HTTPS API (unsigned call, no AWS profile needed).
./assume-role.sh -m curl -v > .creds.json

#    ...or the same exchange through the AWS CLI:
./assume-role.sh -m cli -v > .creds.json

# 3. Use the credentials against S3: allowed under users/<sub>/, denied elsewhere.
./s3-test.sh
```

`s3-test.sh` checks that the credentials can put, list and get under `users/<sub>/`, and are denied at the bucket root and under another user's prefix. It exits non-zero if any check fails. Run any script with `-h` for its options. `.token` and `.creds.json` are gitignored.

### Trust policy checks: `oaud` (`scripts/trust-test.sh`)

The role's trust policy checks `<issuer>:aud` (the client ID, because AWS maps `azp` to it) and `<issuer>:oaud` (the token's original `aud`, i.e. our API). `trust-test.sh` verifies that an access token for our API is accepted, and that an ID token and a token for another API are rejected.

```sh
cd aws/scripts

# Tokens: one login gives the access token and the ID token; a second login targets the other API.
./device-token.sh -i .id_token > .token
./device-token.sh -a https://other.wif > .token-other

./trust-test.sh -v       # -m cli to use the AWS CLI instead of curl
```

Access tokens requested with `openid` carry `aud` as an array (`[api, userinfo]`). The trust policy uses `ForAnyValue:StringEquals` on `oaud`, which matches when any element equals our API. Tokens that do not list our API (ID tokens, tokens for other APIs) are rejected. Re-run `trust-test.sh` whenever the trust policy changes.

## Phase 3

The demo SPA (`spa/`) is not built yet.
