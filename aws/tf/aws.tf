data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.name_prefix}-${data.aws_caller_identity.current.account_id}"

  # Auth0 issues tokens with iss = https://<domain>/ (trailing slash included).
  issuer_url = "https://${var.auth0_domain}/"

  # IAM condition keys / policy variables are prefixed with the provider URL minus the scheme,
  # taken from the resource so they always match what IAM stored.
  oidc_host = replace(aws_iam_openid_connect_provider.auth0.url, "https://", "")

  # AWS maps a token's `azp` claim (when present) to the `aud` condition key, and Auth0 access
  # tokens always carry azp = the requesting client's ID. So IAM sees the *client ID*, not the API audience.
  allowed_client_ids = [auth0_client.spa.client_id, auth0_client.cli.client_id]
}

# --- Identity provider: trust Auth0 as an OIDC issuer ---

resource "aws_iam_openid_connect_provider" "auth0" {
  url            = local.issuer_url
  client_id_list = local.allowed_client_ids
  # thumbprint_list omitted: IAM verifies the JWKS endpoint against its trusted CA library.
}

# --- Role assumed via sts:AssumeRoleWithWebIdentity ---

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.auth0.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = local.allowed_client_ids
    }
  }
}

resource "aws_iam_role" "federated" {
  name                 = "${var.name_prefix}-web-identity"
  description          = "Assumed by Auth0-authenticated users via AssumeRoleWithWebIdentity; scoped to users/<sub>/ in the demo bucket."
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.role_session_duration
}

# &{...} is the aws_iam_policy_document escape for IAM's ${...} policy variables.
# `sub` is available in the role session, so each user is limited to their own prefix.
data "aws_iam_policy_document" "user_prefix_access" {
  statement {
    sid       = "ListOwnPrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.demo.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["users/&{${local.oidc_host}:sub}/*"]
    }
  }

  statement {
    sid       = "ReadWriteOwnObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.demo.arn}/users/&{${local.oidc_host}:sub}/*"]
  }
}

resource "aws_iam_role_policy" "user_prefix_access" {
  name   = "user-prefix-s3-access"
  role   = aws_iam_role.federated.id
  policy = data.aws_iam_policy_document.user_prefix_access.json
}

# --- Bucket ---

resource "aws_s3_bucket" "demo" {
  bucket        = local.bucket_name
  force_destroy = var.bucket_force_destroy
}

resource "aws_s3_bucket_public_access_block" "demo" {
  bucket                  = aws_s3_bucket.demo.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# The SPA calls S3 directly from the browser.
resource "aws_s3_bucket_cors_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  cors_rule {
    allowed_origins = var.spa_origins
    allowed_methods = ["GET", "PUT", "HEAD"]
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
