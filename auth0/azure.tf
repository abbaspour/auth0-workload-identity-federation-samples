# The API whose access tokens are presented to Microsoft Entra ID as the client assertion. Its identifier is the token
# `aud`, and a classic federated credential accepts exactly one audience, so it must equal the credential's audience
# (api://AzureADTokenExchange is Microsoft's recommended value).
resource "auth0_resource_server" "azure_api" {
  name        = "${var.name_prefix} Azure API"
  identifier  = var.azure_api_audience
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

# The Azure demo SPA. Entra does not look at `azp`: a federated credential matches only issuer, subject and audience.
resource "auth0_client" "azure_spa" {
  name            = "${var.name_prefix} Azure SPA"
  description     = "Demo SPA that exchanges its Auth0 access token for Microsoft Entra tokens."
  app_type        = "spa"
  is_first_party  = true
  oidc_conformant = true

  callbacks           = local.azure_spa_origins
  allowed_logout_urls = local.azure_spa_origins
  allowed_origins     = local.azure_spa_origins
  web_origins         = local.azure_spa_origins

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

# Terminal client for the Azure scripts: gets a real user access token via the device authorization flow.
resource "auth0_client" "azure_cli" {
  name            = "${var.name_prefix} Azure CLI (device flow)"
  description     = "Used by azure/scripts to obtain a user access token without a browser redirect."
  app_type        = "native"
  is_first_party  = true
  oidc_conformant = true

  grant_types = ["urn:ietf:params:oauth:grant-type:device_code", "refresh_token"]

  jwt_configuration {
    alg = "RS256"
  }
}

resource "auth0_connection_client" "azure_spa_db" {
  connection_id = auth0_connection.users.id
  client_id     = auth0_client.azure_spa.client_id
}

resource "auth0_connection_client" "azure_cli_db" {
  connection_id = auth0_connection.users.id
  client_id     = auth0_client.azure_cli.client_id
}
