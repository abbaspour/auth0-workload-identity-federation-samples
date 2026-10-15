# The API whose access tokens are presented to sts:AssumeRoleWithWebIdentity.
resource "auth0_resource_server" "aws_api" {
  name        = "${var.name_prefix} AWS API"
  identifier  = var.aws_api_audience
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

# The AWS demo SPA. Its client ID is what AWS sees as the token's `aud` (via `azp`).
resource "auth0_client" "aws_spa" {
  name            = "${var.name_prefix} SPA"
  description     = "Demo SPA that exchanges its Auth0 access token for AWS credentials."
  app_type        = "spa"
  is_first_party  = true
  oidc_conformant = true

  callbacks           = local.aws_spa_origins
  allowed_logout_urls = local.aws_spa_origins
  allowed_origins     = local.aws_spa_origins
  web_origins         = local.aws_spa_origins

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

# Terminal client for the AWS scripts: gets a real user access token via the device authorization flow.
resource "auth0_client" "aws_cli" {
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

resource "auth0_connection_client" "aws_spa_db" {
  connection_id = auth0_connection.users.id
  client_id     = auth0_client.aws_spa.client_id
}

resource "auth0_connection_client" "aws_cli_db" {
  connection_id = auth0_connection.users.id
  client_id     = auth0_client.aws_cli.client_id
}
