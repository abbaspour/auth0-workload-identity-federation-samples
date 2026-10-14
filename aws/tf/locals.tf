locals {
  # The custom domain only becomes the issuer once Auth0 has verified it (DNS in place).
  custom_domain_active = var.auth0_custom_domain != "" && var.auth0_custom_domain_verified

  # Auth0 issues tokens with iss = https://<domain>/ (trailing slash included), where <domain> is the
  # domain the login ran against. Clients (SPA, scripts) must therefore use issuer_domain too.
  issuer_domain = local.custom_domain_active ? var.auth0_custom_domain : var.auth0_domain
  issuer_url    = "https://${local.issuer_domain}/"

  spa_origins = concat(var.spa_origins, var.spa_domain == "" ? [] : ["https://${var.spa_domain}"])
}
