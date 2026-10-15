#!/usr/bin/env bash

set -ueo pipefail

DIR="${BASH_SOURCE[0]%/*}"
[ "$DIR" = "${BASH_SOURCE[0]}" ] && DIR="."
readonly DIR

command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

. "${DIR}/lib.sh"

function usage() {
    cat <<END >&2
USAGE: $0 [-m curl|gcloud] [-f token_file | -t token] [-p provider_audience] [-v|-h]
        -m mode          # curl (Google STS HTTPS API, default) or gcloud (gcloud auth login --cred-file)
        -f file          # file holding the Auth0 access token, or - for stdin (default: ${DIR}/.token)
        -t token         # access token on the command line
        -p audience      # workload identity provider, //iam.googleapis.com/projects/... (default: terraform output workload_identity_provider)
        -h|?             # usage
        -v               # verbose: print the token's claims to stderr

Exchanges the Auth0 access token for a Google federated access token and prints it as JSON on stdout:
{AccessToken, TokenType, ExpiresIn, Subject}. The call is unauthenticated: no Google credentials are needed.

eg,
     $0 -m curl > ${DIR}/.creds.json
END
    exit $1
}

declare MODE='curl'
declare TOKEN_FILE="${DIR}/.token"
declare TOKEN=''
declare PROVIDER=''
declare opt_verbose=0

while getopts ":m:f:t:p:hv?" opt; do
    case ${opt} in
    m) MODE=${OPTARG} ;;
    f) TOKEN_FILE=${OPTARG} ;;
    t) TOKEN=${OPTARG} ;;
    p) PROVIDER=${OPTARG} ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    \?) [[ "${OPTARG}" == "?" ]] && usage 0
        echo >&2 "ERROR: illegal option -- ${OPTARG}"
        usage 1 ;;
    :) echo >&2 "ERROR: option requires an argument -- ${OPTARG}"; usage 1 ;;
    esac
done

if [[ -z "${TOKEN}" ]]; then
    if [[ "${TOKEN_FILE}" == "-" ]]; then
        TOKEN=$(cat)
    else
        [[ -f "${TOKEN_FILE}" ]] || { echo >&2 "ERROR: token file missing: ${TOKEN_FILE} (run device-token.sh first)"; usage 1; }
        TOKEN=$(<"${TOKEN_FILE}")
    fi
fi

[[ -z "${PROVIDER}" ]] && PROVIDER=$(tf_output workload_identity_provider)

[[ -z "${TOKEN}" ]]    && { echo >&2 "ERROR: TOKEN empty";         usage 1; }
[[ -z "${PROVIDER}" ]] && { echo >&2 "ERROR: PROVIDER undefined";  usage 1; }
[[ "${MODE}" == "curl" || "${MODE}" == "gcloud" ]] || { echo >&2 "ERROR: MODE must be curl or gcloud"; usage 1; }

[[ ${opt_verbose} -eq 1 ]] && jwt_claims "${TOKEN}" >&2

# The subject Google evaluates is the `sub` claim (google.subject = assertion.sub)
declare SUBJECT
SUBJECT=$(jwt_claims "${TOKEN}" | jq -r '.sub')
readonly SUBJECT

if [[ "${MODE}" == "curl" ]]; then
    response=$(curl -s --request POST \
        --header 'accept: application/json' \
        --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:token-exchange' \
        --data-urlencode "audience=${PROVIDER}" \
        --data-urlencode 'scope=https://www.googleapis.com/auth/cloud-platform' \
        --data-urlencode 'requested_token_type=urn:ietf:params:oauth:token-type:access_token' \
        --data-urlencode 'subject_token_type=urn:ietf:params:oauth:token-type:jwt' \
        --data-urlencode "subject_token=${TOKEN}" \
        --url 'https://sts.googleapis.com/v1/token')
    result=$(jq -c 'select(.access_token) | {AccessToken: .access_token, TokenType: .token_type, ExpiresIn: .expires_in}' <<< "${response}" 2>/dev/null || true)
else
    command -v gcloud >/dev/null || { echo >&2 "error: gcloud not found"; exit 3; }

    # Isolated gcloud config so nothing touches the user's own gcloud accounts
    tmp=$(mktemp -d)
    readonly tmp
    printf '%s' "${TOKEN}" > "${tmp}/subject-token.txt"

    response=$(CLOUDSDK_CONFIG="${tmp}/config" gcloud iam workload-identity-pools create-cred-config "${PROVIDER#//iam.googleapis.com/}" \
        --credential-source-file="${tmp}/subject-token.txt" --credential-source-type=text \
        --output-file="${tmp}/cred.json" 2>&1 &&
        CLOUDSDK_CONFIG="${tmp}/config" gcloud auth login --cred-file="${tmp}/cred.json" --quiet 2>&1 &&
        CLOUDSDK_CONFIG="${tmp}/config" gcloud auth print-access-token 2>&1) || true
    access_token=$(tail -n 1 <<< "${response}")
    # gcloud only prints the token; its lifetime is not shown (federated tokens last up to an hour)
    result=$(jq -cn --arg t "${access_token}" 'select($t | test("^ya29\\.")) | {AccessToken: $t, TokenType: "Bearer", ExpiresIn: null}' 2>/dev/null || true)
    /bin/rm -rf "${tmp}"
fi

[[ -n "${result}" ]] || { echo >&2 "ERROR: token exchange failed:"; echo >&2 "${response}"; exit 1; }

jq --arg sub "${SUBJECT}" '. + {Subject: $sub}' <<< "${result}"
