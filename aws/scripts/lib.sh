#!/usr/bin/env bash
# Sourced by the other scripts. Not meant to be executed directly.

# Value of a Terraform output from aws/tf (empty when unavailable)
function tf_output() {
    terraform -chdir="${DIR}/../tf" output -raw "$1" 2>/dev/null || true
}

# Print the payload of a JWT as JSON. Handles base64url.
function jwt_claims() {
    jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | @base64d | fromjson' <<< "$1"
}
