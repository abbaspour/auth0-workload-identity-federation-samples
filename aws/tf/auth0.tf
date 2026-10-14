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

# The demo SPA (Phase 3). Its client ID is what AWS sees as the token's `aud` (via `azp`).
resource "auth0_client" "spa" {
  name            = "${var.name_prefix} SPA"
  description     = "Demo SPA that exchanges its Auth0 access token for AWS credentials."
  app_type        = "spa"
  is_first_party  = true
  oidc_conformant = true

  callbacks           = var.spa_origins
  allowed_logout_urls = var.spa_origins
  allowed_origins     = var.spa_origins
  web_origins         = var.spa_origins

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

data "auth0_connection" "db" {
  name = var.db_connection_name
}

resource "auth0_connection_client" "spa_db" {
  connection_id = data.auth0_connection.db.id
  client_id     = auth0_client.spa.client_id
}

resource "auth0_user" "test" {
  connection_name = data.auth0_connection.db.name
  email           = var.test_user_email
  email_verified  = true
  password        = var.test_user_password
}
