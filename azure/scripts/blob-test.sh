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
USAGE: $0 [-f creds_file] [-a account] [-n container] [-i] [-v|-h]
        -f file        # token JSON from exchange.sh (default: ${DIR}/.creds.json)
        -a account     # storage account (default: terraform output storage_account_name)
        -n container   # container (default: terraform output container_name)
        -i             # expect per-user isolation: another user's prefix must be denied
        -h|?           # usage
        -v             # verbose: show the response body of each call

Uses the Entra access token against the Blob Storage REST API. Checks that users/<sub>/ works, that a bad token is
rejected and, without -i, that another prefix is also reachable. The role assignment in azure/tf gives the whole app
registration, and so every user with a federated credential, the same container access, so isolation is not
expected by default. Exits non-zero if any check fails.
END
    exit $1
}

declare CREDS_FILE="${DIR}/.creds.json"
declare ACCOUNT=''
declare CONTAINER=''
declare opt_isolation=0
declare opt_verbose=0

while getopts ":f:a:n:ihv?" opt; do
    case ${opt} in
    f) CREDS_FILE=${OPTARG} ;;
    a) ACCOUNT=${OPTARG} ;;
    n) CONTAINER=${OPTARG} ;;
    i) opt_isolation=1 ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    \?) [[ "${OPTARG}" == "?" ]] && usage 0
        echo >&2 "ERROR: illegal option -- ${OPTARG}"
        usage 1 ;;
    :) echo >&2 "ERROR: option requires an argument -- ${OPTARG}"; usage 1 ;;
    esac
done

[[ -z "${ACCOUNT}" ]]   && ACCOUNT=$(tf_output storage_account_name)
[[ -z "${CONTAINER}" ]] && CONTAINER=$(tf_output container_name)

[[ -f "${CREDS_FILE}" ]] || { echo >&2 "ERROR: token file missing: ${CREDS_FILE} (run exchange.sh first)"; usage 1; }
[[ -z "${ACCOUNT}" ]]    && { echo >&2 "ERROR: ACCOUNT undefined";   usage 1; }
[[ -z "${CONTAINER}" ]]  && { echo >&2 "ERROR: CONTAINER undefined"; usage 1; }

ACCESS_TOKEN=$(jq -r '.AccessToken' "${CREDS_FILE}")
SUBJECT=$(jq -r '.Subject' "${CREDS_FILE}")
readonly ACCESS_TOKEN SUBJECT

declare -r API="https://${ACCOUNT}.blob.core.windows.net/${CONTAINER}"
declare -r API_VERSION='2023-11-03'   # any version from 2017-11-09 on accepts OAuth bearer tokens
declare -r OWN_PREFIX="users/${SUBJECT}/"
declare -r OTHER_PREFIX="users/someone-else/"
declare -r KEY="${OWN_PREFIX}hello-$(date +%s).txt"
declare -r OTHER_KEY="${OTHER_PREFIX}hello-$(date +%s).txt"

tmp=$(mktemp -d)
readonly tmp
echo "hello from ${SUBJECT}" > "${tmp}/body.txt"

function uri() { jq -rn --arg v "$1" '$v | @uri'; }

# Blob names keep their "/" separators in the URL path; every segment is encoded ("|" in an Auth0 sub becomes %7C)
function blob_path() { jq -rn --arg v "$1" '$v | split("/") | map(@uri) | join("/")'; }

declare -i failures=0

# call <token> <method> <url> [extra curl args...]: prints the HTTP status, the body goes to ${tmp}/out
function call() {
    local token=$1 method=$2 url=$3
    shift 3
    curl -s -o "${tmp}/out" -w '%{http_code}' --request "${method}" \
        --header "Authorization: Bearer ${token}" --header "x-ms-version: ${API_VERSION}" "$@" --url "${url}"
}

# check <allow|deny> <description> <token> <method> <url> [extra curl args...]
function check() {
    local expect=$1 description=$2
    shift 2
    local status
    status=$(call "$@")

    local ok=0
    if [[ "${expect}" == "allow" && ${status} =~ ^2 ]]; then
        ok=1
    elif [[ "${expect}" == "deny" && ( ${status} == 401 || ${status} == 403 ) ]]; then
        ok=1
    fi

    if [[ ${ok} -eq 1 ]]; then
        printf 'PASS  %-6s %s\n' "${expect}" "${description}"
        [[ ${opt_verbose} -eq 1 ]] && echo >&2 "      ${status}: $(<"${tmp}/out")"
    else
        printf 'FAIL  %-6s %s\n' "${expect}" "${description}"
        failures+=1
        echo >&2 "      HTTP ${status}: $(<"${tmp}/out")"
    fi
    return 0
}

echo "subject:   ${SUBJECT}"
echo "container: ${API}"
echo

declare other_expect='allow'
[[ ${opt_isolation} -eq 1 ]] && other_expect='deny'

check allow "put    ${KEY}"          "${ACCESS_TOKEN}" PUT "${API}/$(blob_path "${KEY}")" \
    --header 'x-ms-blob-type: BlockBlob' --header 'Content-Type: text/plain' --data-binary "@${tmp}/body.txt"
check allow "list   ${OWN_PREFIX}"   "${ACCESS_TOKEN}" GET "${API}?restype=container&comp=list&prefix=$(uri "${OWN_PREFIX}")"
check allow "get    ${KEY}"          "${ACCESS_TOKEN}" GET "${API}/$(blob_path "${KEY}")"
check deny  "list   with an invalid token" "not-a-token" GET "${API}?restype=container&comp=list&prefix=$(uri "${OWN_PREFIX}")"
check "${other_expect}" "list   ${OTHER_PREFIX}" "${ACCESS_TOKEN}" GET "${API}?restype=container&comp=list&prefix=$(uri "${OTHER_PREFIX}")"
check "${other_expect}" "put    ${OTHER_KEY}"    "${ACCESS_TOKEN}" PUT "${API}/$(blob_path "${OTHER_KEY}")" \
    --header 'x-ms-blob-type: BlockBlob' --header 'Content-Type: text/plain' --data-binary "@${tmp}/body.txt"

echo
if [[ ${failures} -eq 0 ]]; then
    echo "All checks passed."
else
    echo >&2 "${failures} check(s) failed."
    exit 1
fi
