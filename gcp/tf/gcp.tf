locals {
  bucket_name = "${var.name_prefix}-${var.gcp_project_id}"

  # Auth0 access tokens always carry azp = the requesting client's ID, so the provider's
  # attribute condition pins the pool to the two clients of this demo (SPA and CLI).
  allowed_client_ids = [local.auth0.gcp_spa_client_id, local.auth0.gcp_cli_client_id]
}

# --- APIs ---

resource "google_project_service" "apis" {
  for_each = toset(["iam.googleapis.com", "sts.googleapis.com", "storage.googleapis.com"])

  service            = each.value
  disable_on_destroy = false
}

# --- Identity provider: trust Auth0 as an OIDC issuer ---

resource "google_iam_workload_identity_pool" "auth0" {
  workload_identity_pool_id = var.name_prefix
  display_name              = "Auth0 (${var.name_prefix})"
  description               = "Federates Auth0-issued access tokens."

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "auth0" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.auth0.workload_identity_pool_id
  workload_identity_pool_provider_id = "auth0"
  display_name                       = "Auth0 OIDC"

  attribute_mapping = {
    "google.subject" = "assertion.sub"
    "attribute.azp"  = "assertion.azp"
  }

  # Only tokens issued to our SPA or CLI client are accepted (AWS does the same through `azp` -> `aud`).
  attribute_condition = "assertion.azp in [${join(", ", [for id in local.allowed_client_ids : "'${id}'"])}]"

  oidc {
    # Google fetches <issuer>/.well-known/openid-configuration; the custom domain must be verified first.
    issuer_uri = local.issuer_url

    # The token's `aud` must contain our API (Auth0 access tokens requested with `openid` carry [api, userinfo]).
    allowed_audiences = [local.auth0.gcp_api_audience]
  }
}

# --- Bucket ---

resource "google_storage_bucket" "demo" {
  name          = local.bucket_name
  location      = var.gcp_region
  force_destroy = var.bucket_force_destroy

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # The SPA calls Cloud Storage directly from the browser.
  cors {
    origin          = local.spa_origins
    method          = ["GET", "POST", "PUT", "HEAD"]
    response_header = ["Authorization", "Content-Type", "x-goog-user-project"]
    max_age_seconds = 3000
  }

  # Demo hygiene: uploads are temporary.
  lifecycle_rule {
    condition {
      age            = var.object_expiration_days
      matches_prefix = ["users/"]
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.apis]
}

# Direct resource access: the federated principal itself is granted the role, with no service account
# impersonation. This grants every identity in the pool access to the bucket. Unlike the AWS demo, nothing
# restricts a user to their own users/<sub>/ prefix (IAM has no `sub` policy variable); see the README.
resource "google_storage_bucket_iam_member" "pool_object_user" {
  bucket = google_storage_bucket.demo.name
  role   = "roles/storage.objectUser"
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.auth0.name}/*"
}
