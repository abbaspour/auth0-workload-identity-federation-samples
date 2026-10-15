#!/usr/bin/env bash

set -ueo pipefail

DIR="${BASH_SOURCE[0]%/*}"
[ "$DIR" = "${BASH_SOURCE[0]}" ] && DIR="."
readonly DIR

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null   || { echo >&2 "error: jq not found";   exit 3; }

. "${DIR}/lib.sh"

function usage() {
    cat <<END >&2
USAGE: $0 [-d domain] [-c client_id] [-a audience] [-s scope] [-i id_token_file] [-v|-h]
        -d domain      # Auth0 domain (default: terraform output auth0_issuer_domain)
        -c client_id   # device-flow client (default: terraform output cli_client_id)
        -a audience    # API audience (default: terraform output api_audience)
        -s scope       # comma-separated scopes (default: openid)
        -i file        # also save the ID token to this file (for negative tests)
        -h|?           # usage
        -v             # verbose: print decoded token claims to stderr

Prints the access token on stdout; prompts go to stderr.

eg,
     TOKEN=\$($0)
END
    exit $1
}

declare DOMAIN=''
declare CLIENT_ID=''
declare AUDIENCE=''
declare SCOPE='openid'
declare ID_TOKEN_FILE=''
declare opt_verbose=0

while getopts ":d:c:a:s:i:hv?" opt; do
    case ${opt} in
    d) DOMAIN=${OPTARG} ;;
    c) CLIENT_ID=${OPTARG} ;;
    a) AUDIENCE=${OPTARG} ;;
    s) SCOPE=$(echo "${OPTARG}" | tr ',' ' ') ;;
    i) ID_TOKEN_FILE=${OPTARG} ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    \?) [[ "${OPTARG}" == "?" ]] && usage 0
        echo >&2 "ERROR: illegal option -- ${OPTARG}"
        usage 1 ;;
    :) echo >&2 "ERROR: option requires an argument -- ${OPTARG}"; usage 1 ;;
    esac
done

[[ -z "${DOMAIN}" ]]    && DOMAIN=$(tf_output auth0_issuer_domain)
[[ -z "${CLIENT_ID}" ]] && CLIENT_ID=$(tf_output cli_client_id)
[[ -z "${AUDIENCE}" ]]  && AUDIENCE=$(tf_output api_audience)

[[ -z "${DOMAIN}" ]]    && { echo >&2 "ERROR: DOMAIN undefined";    usage 1; }
[[ -z "${CLIENT_ID}" ]] && { echo >&2 "ERROR: CLIENT_ID undefined"; usage 1; }
[[ -z "${AUDIENCE}" ]]  && { echo >&2 "ERROR: AUDIENCE undefined";  usage 1; }

device=$(curl -s --request POST \
    --url "https://${DOMAIN}/oauth/device/code" \
    --data-urlencode "client_id=${CLIENT_ID}" \
    --data-urlencode "scope=${SCOPE}" \
    --data-urlencode "audience=${AUDIENCE}")
readonly device

device_code=$(jq -r '.device_code // empty' <<< "${device}")
readonly device_code
[[ -n "${device_code}" ]] || { echo >&2 "ERROR: device authorization failed: ${device}"; exit 1; }

echo >&2 "Open: $(jq -r '.verification_uri_complete' <<< "${device}")"
echo >&2 "Code: $(jq -r '.user_code' <<< "${device}")  (log in as the Terraform test user)"

declare -i interval
interval=$(jq -r '.interval // 5' <<< "${device}")
declare -i deadline
deadline=$(( $(date +%s) + $(jq -r '.expires_in // 900' <<< "${device}") ))

while [[ $(date +%s) -lt ${deadline} ]]; do
    sleep "${interval}"
    response=$(curl -s --request POST \
        --url "https://${DOMAIN}/oauth/token" \
        --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
        --data-urlencode "device_code=${device_code}" \
        --data-urlencode "client_id=${CLIENT_ID}")

    access_token=$(jq -r '.access_token // empty' <<< "${response}")
    if [[ -n "${access_token}" ]]; then
        [[ ${opt_verbose} -eq 1 ]] && jwt_claims "${access_token}" >&2
        [[ -n "${ID_TOKEN_FILE}" ]] && jq -r '.id_token // empty' <<< "${response}" > "${ID_TOKEN_FILE}"
        echo "${access_token}"
        exit 0
    fi

    error=$(jq -r '.error // "unknown_error"' <<< "${response}")
    case ${error} in
    authorization_pending) ;;
    slow_down) interval=$((interval + 5)) ;;
    *) echo >&2 "ERROR: ${error}: $(jq -r '.error_description // empty' <<< "${response}")"; exit 1 ;;
    esac
done

echo >&2 "ERROR: timed out waiting for login"
exit 1
