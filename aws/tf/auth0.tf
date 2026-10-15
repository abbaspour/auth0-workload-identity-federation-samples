# Auth0 is managed by the shared root in ../../auth0 (apply it first). Everything this root needs from it
# is read from its outputs: the issuer, the client IDs and the API audience.
data "terraform_remote_state" "auth0" {
  backend = "local"

  config = {
    path = "${path.module}/../../auth0/terraform.tfstate"
  }
}

locals {
  auth0 = data.terraform_remote_state.auth0.outputs

  issuer_domain = local.auth0.auth0_issuer_domain
  issuer_url    = local.auth0.auth0_issuer
  spa_origins   = local.auth0.aws_spa_origins
}
