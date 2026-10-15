# The API whose access tokens are presented to Google STS (token exchange).
resource "auth0_resource_server" "gcp_api" {
  name        = "${var.name_prefix} GCP API"
  identifier  = var.gcp_api_audience
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

# The GCP demo SPA. Its client ID is checked in the workload identity provider's attribute condition (via `azp`).
resource "auth0_client" "gcp_spa" {
  name            = "${var.name_prefix} GCP SPA"
  description     = "Demo SPA that exchanges its Auth0 access token for Google Cloud credentials."
  app_type        = "spa"
  is_first_party  = true
  oidc_conformant = true

  callbacks           = local.gcp_spa_origins
  allowed_logout_urls = local.gcp_spa_origins
  allowed_origins     = local.gcp_spa_origins
  web_origins         = local.gcp_spa_origins

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

# Terminal client for the GCP scripts: gets a real user access token via the device authorization flow.
resource "auth0_client" "gcp_cli" {
  name            = "${var.name_prefix} GCP CLI (device flow)"
  description     = "Used by gcp/scripts to obtain a user access token without a browser redirect."
  app_type        = "native"
  is_first_party  = true
  oidc_conformant = true

  grant_types = ["urn:ietf:params:oauth:grant-type:device_code", "refresh_token"]

  jwt_configuration {
    alg = "RS256"
  }
}

resource "auth0_connection_client" "gcp_spa_db" {
  connection_id = auth0_connection.users.id
  client_id     = auth0_client.gcp_spa.client_id
}

resource "auth0_connection_client" "gcp_cli_db" {
  connection_id = auth0_connection.users.id
  client_id     = auth0_client.gcp_cli.client_id
}
