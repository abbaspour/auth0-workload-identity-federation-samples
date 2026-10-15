# Auth0 Workload Identity Federation examples

An Auth0-issued access token is exchanged for short-lived cloud credentials through each provider's Workload Identity Federation, with no long-lived cloud keys. Each sample has Terraform, verification scripts and a small demo SPA where a logged-in user lists and uploads files in a storage bucket.

| Folder            | What it is                                                                                                                           |
|-------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| [`auth0/`](auth0) | Shared Auth0 setup (Terraform): custom domain, user database, test user, and the API and clients of each cloud demo. Apply it first. |
| [`aws/`](aws)     | AWS: IAM OIDC provider + `AssumeRoleWithWebIdentity` → S3, one prefix per user                                                       |
| [`gcp/`](gcp)     | Google Cloud: workload identity pool + STS token exchange → Cloud Storage (direct access)                                            |
| [`azure/`](azure) | Azure: app registration with federated credentials + Entra token exchange → Blob Storage                                             |
