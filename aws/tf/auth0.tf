# The API whose access tokens are presented to sts:AssumeRoleWithWebIdentity.
resource "auth0_resource_server" "aws" {
  name        = "${var.name_prefix} AWS API"
  identifier  = var.api_audience
  signing_alg = "RS256"

  token_lifetime                                  = 3600
  allow_offline_access                            = false
  skip_consent_for_verifiable_first_party_clients = true

  subject_type_authorization {
    user {
      policy = "allow_all"
    }
  }
}

# A second API that the AWS role must NOT accept tokens for (negative test for the oaud condition).
resource "auth0_resource_server" "other" {
  name        = "${var.name_prefix} Other API (negative test)"
  identifier  = var.other_api_audience
  signing_alg = "RS256"

  token_lifetime                                  = 3600
  skip_consent_for_verifiable_first_party_clients = true

  subject_type_authorization {
    user {
      policy = "allow_all"
    }
  }
}

# The demo SPA (Phase 3). Its client ID is what AWS sees as the token's `aud` (via `azp`).
resource "auth0_client" "spa" {
  name            = "${var.name_prefix} SPA"
  description     = "Demo SPA that exchanges its Auth0 access token for AWS credentials."
  app_type        = "spa"
  is_first_party  = true
  oidc_conformant = true

  callbacks           = local.spa_origins
  allowed_logout_urls = local.spa_origins
  allowed_origins     = local.spa_origins
  web_origins         = local.spa_origins

  grant_types = ["authorization_code", "refresh_token"]

  jwt_configuration {
    alg = "RS256"
  }

  refresh_token {
    rotation_type   = "rotating"
    expiration_type = "expiring"
    token_lifetime  = 2592000
    leeway          = 5
  }
}

# Terminal client for Phase 2: gets a real user access token via the device authorization flow.
resource "auth0_client" "cli" {
  name            = "${var.name_prefix} CLI (device flow)"
  description     = "Used by aws/scripts to obtain a user access token without a browser redirect."
  app_type        = "native"
  is_first_party  = true
  oidc_conformant = true

  grant_types = ["urn:ietf:params:oauth:grant-type:device_code", "refresh_token"]

  jwt_configuration {
    alg = "RS256"
  }
}

# Dedicated database connection with sign-up disabled: the app is public, so only users created
# here (by Terraform or an admin) can log in and get S3 access.
resource "auth0_connection" "users" {
  name     = "users"
  strategy = "auth0"

  options {
    disable_signup         = true
    brute_force_protection = true
    password_policy        = "fair"
  }
}

resource "auth0_connection_client" "spa_db" {
  connection_id = auth0_connection.users.id
  client_id     = auth0_client.spa.client_id
}

resource "auth0_connection_client" "cli_db" {
  connection_id = auth0_connection.users.id
  client_id     = auth0_client.cli.client_id
}

resource "auth0_user" "test" {
  connection_name = auth0_connection.users.name
  email           = var.test_user_email
  email_verified  = true
  password        = var.test_user_password
}

# Tenant-wide custom domain (one per tenant on most plans; later Azure/GCP demos share it).
# Stage 1 creates it and outputs the DNS record to add; stage 2 (auth0_custom_domain_verified) verifies it.
resource "auth0_custom_domain" "main" {
  count = var.auth0_custom_domain == "" ? 0 : 1

  domain     = var.auth0_custom_domain
  type       = "auth0_managed_certs"
  tls_policy = "recommended"
}

resource "auth0_custom_domain_verification" "main" {
  count = local.custom_domain_active ? 1 : 0

  custom_domain_id = auth0_custom_domain.main[0].id

  timeouts {
    create = "15m"
  }
}
