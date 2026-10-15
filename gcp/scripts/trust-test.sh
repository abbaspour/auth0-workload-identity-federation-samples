#!/usr/bin/env bash

set -ueo pipefail

DIR="${BASH_SOURCE[0]%/*}"
[ "$DIR" = "${BASH_SOURCE[0]}" ] && DIR="."
readonly DIR

command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-m curl|gcloud] [-a good_token_file] [-i id_token_file] [-o other_api_token_file] [-v|-h]
        -m mode        # curl (default) or gcloud, passed to exchange.sh
        -a file        # access token for our API: must be accepted (default: ${DIR}/.token)
        -i file        # ID token: must be rejected (default: ${DIR}/.id_token)
        -o file        # access token for the other API: must be rejected (default: ${DIR}/.token-other)
        -h|?           # usage
        -v             # verbose: show the STS error for rejected tokens

Checks the workload identity provider (allowed_audiences and the azp attribute condition). A token file that does
not exist is skipped. Exits non-zero if any executed check fails.

eg,
     ${DIR}/device-token.sh -i ${DIR}/.id_token > ${DIR}/.token
     ${DIR}/device-token.sh -a https://other.wif > ${DIR}/.token-other
     $0
END
    exit $1
}

declare MODE='curl'
declare GOOD="${DIR}/.token"
declare ID="${DIR}/.id_token"
declare OTHER="${DIR}/.token-other"
declare opt_verbose=0

while getopts ":m:a:i:o:hv?" opt; do
    case ${opt} in
    m) MODE=${OPTARG} ;;
    a) GOOD=${OPTARG} ;;
    i) ID=${OPTARG} ;;
    o) OTHER=${OPTARG} ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    \?) [[ "${OPTARG}" == "?" ]] && usage 0
        echo >&2 "ERROR: illegal option -- ${OPTARG}"
        usage 1 ;;
    :) echo >&2 "ERROR: option requires an argument -- ${OPTARG}"; usage 1 ;;
    esac
done

declare -i failures=0
declare -i executed=0

# check <accept|reject> <description> <token_file>
function check() {
    local expect=$1 description=$2 file=$3
    if [[ ! -f "${file}" || ! -s "${file}" ]]; then
        printf 'SKIP  %-7s %s (no %s)\n' "${expect}" "${description}" "${file}"
        return 0
    fi
    executed+=1

    local out rc=0
    out=$("${DIR}/exchange.sh" -m "${MODE}" -f "${file}" 2>&1) || rc=$?

    if [[ "${expect}" == "accept" && ${rc} -eq 0 ]] || [[ "${expect}" == "reject" && ${rc} -ne 0 ]]; then
        printf 'PASS  %-7s %s\n' "${expect}" "${description}"
        [[ "${expect}" == "reject" && ${opt_verbose} -eq 1 ]] && echo >&2 "      ${out//$'\n'/$'\n      '}"
    else
        printf 'FAIL  %-7s %s\n' "${expect}" "${description}"
        failures+=1
        # An unexpectedly accepted token returns credentials: show who was assumed, never the secrets
        [[ ${rc} -eq 0 ]] && out=$(jq -c '{unexpectedly_accepted: {Subject}}' <<< "${out}")
        echo >&2 "      ${out//$'\n'/$'\n      '}"
    fi
    return 0
}

check accept "access token for our API"           "${GOOD}"
check reject "ID token"                           "${ID}"
check reject "access token for another API"       "${OTHER}"

echo
[[ ${executed} -gt 0 ]] || { echo >&2 "No token files found; nothing was checked."; exit 1; }
if [[ ${failures} -eq 0 ]]; then
    echo "All executed checks passed."
else
    echo >&2 "${failures} check(s) failed."
    exit 1
fi
