#!/usr/bin/env bash

set -ueo pipefail

DIR="${BASH_SOURCE[0]%/*}"
[ "$DIR" = "${BASH_SOURCE[0]}" ] && DIR="."
readonly DIR

command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

. "${DIR}/lib.sh"

function usage() {
    cat <<END >&2
USAGE: $0 [-m curl|az] [-f token_file | -t token] [-T tenant_id] [-c client_id] [-s scope] [-v|-h]
        -m mode          # curl (Entra token endpoint over HTTPS, default) or az (az login --federated-token)
        -f file          # file holding the Auth0 access token, or - for stdin (default: ${DIR}/.token)
        -t token         # access token on the command line
        -T tenant        # Entra tenant ID (default: terraform output azure_tenant_id)
        -c client_id     # application (client) ID of the app registration (default: terraform output azure_client_id)
        -s scope         # resource scope to request (default: terraform output storage_scope)
        -h|?             # usage
        -v               # verbose: print the token's claims to stderr

Exchanges the Auth0 access token for a Microsoft Entra access token and prints it as JSON on stdout:
{AccessToken, TokenType, ExpiresIn, Subject}. The Auth0 token is the client assertion of a client_credentials
request, so no Azure credentials or secrets are needed.

eg,
     $0 -m curl > ${DIR}/.creds.json
END
    exit $1
}

declare MODE='curl'
declare TOKEN_FILE="${DIR}/.token"
declare TOKEN=''
declare TENANT=''
declare CLIENT_ID=''
declare SCOPE=''
declare opt_verbose=0

while getopts ":m:f:t:T:c:s:hv?" opt; do
    case ${opt} in
    m) MODE=${OPTARG} ;;
    f) TOKEN_FILE=${OPTARG} ;;
    t) TOKEN=${OPTARG} ;;
    T) TENANT=${OPTARG} ;;
    c) CLIENT_ID=${OPTARG} ;;
    s) SCOPE=${OPTARG} ;;
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

[[ -z "${TENANT}" ]]    && TENANT=$(tf_output azure_tenant_id)
[[ -z "${CLIENT_ID}" ]] && CLIENT_ID=$(tf_output azure_client_id)
[[ -z "${SCOPE}" ]]     && SCOPE=$(tf_output storage_scope)

[[ -z "${TOKEN}" ]]     && { echo >&2 "ERROR: TOKEN empty";        usage 1; }
[[ -z "${TENANT}" ]]    && { echo >&2 "ERROR: TENANT undefined";    usage 1; }
[[ -z "${CLIENT_ID}" ]] && { echo >&2 "ERROR: CLIENT_ID undefined"; usage 1; }
[[ -z "${SCOPE}" ]]     && { echo >&2 "ERROR: SCOPE undefined";     usage 1; }
[[ "${MODE}" == "curl" || "${MODE}" == "az" ]] || { echo >&2 "ERROR: MODE must be curl or az"; usage 1; }

[[ ${opt_verbose} -eq 1 ]] && jwt_claims "${TOKEN}" >&2

# The subject the federated credential must match is the `sub` claim
declare SUBJECT
SUBJECT=$(jwt_claims "${TOKEN}" | jq -r '.sub')
readonly SUBJECT

if [[ "${MODE}" == "curl" ]]; then
    command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }

    response=$(curl -s --request POST \
        --header 'accept: application/json' \
        --data-urlencode 'grant_type=client_credentials' \
        --data-urlencode "client_id=${CLIENT_ID}" \
        --data-urlencode "scope=${SCOPE}" \
        --data-urlencode 'client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer' \
        --data-urlencode "client_assertion=${TOKEN}" \
        --url "https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token")
    result=$(jq -c 'select(.access_token) | {AccessToken: .access_token, TokenType: .token_type, ExpiresIn: .expires_in}' <<< "${response}" 2>/dev/null || true)
else
    command -v az >/dev/null || { echo >&2 "error: az not found"; exit 3; }

    # Isolated Azure CLI config so nothing touches the user's own az login. The principal has a role on the
    # container only, hence --allow-no-subscriptions.
    tmp=$(mktemp -d)
    readonly tmp

    response=$(AZURE_CONFIG_DIR="${tmp}" az login --service-principal --username "${CLIENT_ID}" --tenant "${TENANT}" \
        --federated-token "${TOKEN}" --allow-no-subscriptions --output none 2>&1 &&
        AZURE_CONFIG_DIR="${tmp}" az account get-access-token --resource "${SCOPE%/.default}" --output json 2>&1) || true
    result=$(jq -c 'select(.accessToken) | {AccessToken: .accessToken, TokenType: (.tokenType // "Bearer"), ExpiresIn: (if .expires_on then (.expires_on | tonumber - now | floor) else null end)}' <<< "${response}" 2>/dev/null || true)
    /bin/rm -rf "${tmp}"
fi

if [[ -z "${result}" ]]; then
    echo >&2 "ERROR: token exchange failed:"
    echo >&2 "$(jq -r '"\(.error // "error"): \(.error_description // "")"' <<< "${response}" 2>/dev/null || echo "${response}")"
    exit 1
fi

jq --arg sub "${SUBJECT}" '. + {Subject: $sub}' <<< "${result}"
