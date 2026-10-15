# Tenant-wide custom domain (one per tenant on most plans; shared by every cloud demo).
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

# Dedicated database connection with sign-up disabled: the apps are public, so only users created
# here (by Terraform or an admin) can log in and get cloud access.
resource "auth0_connection" "users" {
  name     = "users"
  strategy = "auth0"

  options {
    disable_signup         = true
    brute_force_protection = true
    password_policy        = "fair"
  }
}

resource "auth0_user" "test" {
  connection_name = auth0_connection.users.name
  email           = var.test_user_email
  email_verified  = true
  password        = var.test_user_password
}

# A second API that the cloud trusts must NOT accept tokens for (negative test for the audience check).
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
