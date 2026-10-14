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

### Custom domain (two stages)

The tenant gets an Auth0-managed custom domain (`auth0_custom_domain` in `tf/auth0.tf`), e.g. `id.wif.abbaspour.net`. Tokens issued through it carry `iss = https://id.wif.abbaspour.net/`, so once it is active the IAM OIDC provider trusts that issuer **only**, and the SPA and scripts log in against it (the `auth0_issuer_domain` output). Terraform's own Management API calls keep using `auth0_domain`.

1. Set `auth0_custom_domain = "id.wif.abbaspour.net"` in `terraform.auth.tfvars`, then `make plan && make apply`.
2. `make output`: `custom_domain_dns_records` lists the record to create (type, host, target). Add it in your DNS zone.
3. Set `auth0_custom_domain_verified = true`, then `make plan && make apply`. This verifies the domain, replaces the IAM OIDC provider with the custom-domain issuer and updates the role trust. If IAM reports it cannot fetch the discovery document, the certificate is still being issued: apply again in a few minutes.
4. Existing access tokens (old `iss`) stop working. Mint new ones with `scripts/device-token.sh`, and regenerate the SPA config with `scripts/spa-env.sh`.

A tenant normally has one custom domain, so later Azure and GCP demos share it rather than creating their own.

### Deployed SPA host and sign-ups

- `spa_domain = "aws.wif.abbaspour.net"` adds `https://aws.wif.abbaspour.net` to the SPA's Auth0 callback, logout and web-origin URLs and to the S3 CORS origins (alongside `spa_origins`). It must match the route in `spa/wrangler.jsonc`.
- The SPA, CLI client and test user use a dedicated database connection (`<name_prefix>-users`) with **sign-up disabled**, because the deployed app is public. Only users created by Terraform or an admin can log in. Passwords must meet the connection's "fair" policy (8+ characters with upper case, lower case and a number).
- Uploads under `users/` expire after `object_expiration_days` (default 7), and the SPA rejects files over 10 MB (IAM cannot cap object size).
- Moving to the dedicated connection replaces the test user, which gets a new `sub`. Objects uploaded as the old user stay in the bucket under the old prefix until they expire.

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

## Phase 3: demo SPA (`spa/`)

A vanilla-JS Vite app. The user logs in with Auth0 (`@auth0/auth0-spa-js`, authorization code + PKCE, requesting the API audience). The browser then calls `sts:AssumeRoleWithWebIdentity` with the access token (`@aws-sdk/client-sts`, unsigned) and uses the temporary credentials to list, upload and download objects under `users/<sub>/` (`@aws-sdk/client-s3`, straight from the browser). There is no backend and no AWS keys in the app.

![Sequence diagram of the SPA flow](spa/public/sequence.svg)

The diagram source is [`spa/sequence.puml`](spa/sequence.puml). After editing it, run `make diagram` in `aws/spa` (needs `plantuml` and `graphviz`) to regenerate the committed `spa/public/sequence.svg`, which the SPA also shows under its login button.

```sh
cd aws/spa
../scripts/spa-env.sh     # writes .env.local from terraform output (gitignored)
npm install
npm run dev               # http://localhost:5173 (the port is fixed: it is the Auth0 callback and S3 CORS origin)
npm test                  # unit tests
```

The same goals exist as `make` targets in `aws/spa` (`make dev`, `build`, `preview`, `test`, `deploy`, `diagram`; they run `npm install` first when needed). `make help` lists them.

Log in as the Terraform test user (sign-up is disabled, so only that user can log in). The page shows the token claims AWS evaluates, the assumed role session, when the credentials expire, and your files.

How it works:

| File | Role |
|---|---|
| `src/auth.js` | Auth0 login, redirect callback, access token |
| `src/aws.js` | STS exchange, S3 list/upload/download |
| `src/credentials.js` | Caches credentials, renews them (new Auth0 token + STS) 5 minutes before expiry |
| `src/keys.js` | `users/<sub>/` prefix and key building, shared contract with the role policy |
| `src/main.js` | UI |

### Deploying to Cloudflare Workers

`wrangler.jsonc` configures an assets-only Worker (no script) that serves the Vite build as a single-page app on the custom domain `aws.wif.abbaspour.net`. To use another host, change `routes[0].pattern` and set the same value as `spa_domain` in Terraform.

```sh
cd aws/spa
../scripts/spa-env.sh     # the build bakes these values in; run it again after the custom domain is active
npm run deploy            # vite build && wrangler deploy
```

`wrangler` must be logged in (`npx wrangler login`) to an account that owns the `abbaspour.net` zone. With the custom domain, the Auth0 domain and the SPA share the site `abbaspour.net`, so silent login on page reload works without third-party cookies.

Notes:

- The app never shows the secret key or session token, only the access key ID.
- A page reload relies on Auth0's silent authentication. Browsers that block third-party cookies show the login button again; the Auth0 session makes the second login instant. Refresh tokens are not used.
- Uploads read the whole file into memory, which is fine for a demo but not for large files.
- S3 object names are untrusted input and are rendered with `textContent` only.
