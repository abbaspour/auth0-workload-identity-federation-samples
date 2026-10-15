locals {
  # The custom domain only becomes the issuer once Auth0 has verified it (DNS in place).
  custom_domain_active = var.auth0_custom_domain != "" && var.auth0_custom_domain_verified

  # Auth0 issues tokens with iss = https://<domain>/ (trailing slash included), where <domain> is the
  # domain the login ran against. Clients (SPA, scripts) and the cloud trust configs must use issuer_domain too.
  issuer_domain = local.custom_domain_active ? var.auth0_custom_domain : var.auth0_domain
  issuer_url    = "https://${local.issuer_domain}/"

  aws_spa_origins = concat(var.aws_spa_origins, var.aws_spa_domain == "" ? [] : ["https://${var.aws_spa_domain}"])
  gcp_spa_origins = concat(var.gcp_spa_origins, var.gcp_spa_domain == "" ? [] : ["https://${var.gcp_spa_domain}"])
}
