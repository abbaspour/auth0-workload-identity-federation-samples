#!/usr/bin/env bash

set -ueo pipefail

DIR="${BASH_SOURCE[0]%/*}"
[ "$DIR" = "${BASH_SOURCE[0]}" ] && DIR="."
readonly DIR

command -v aws >/dev/null || { echo >&2 "error: aws not found"; exit 3; }
command -v jq >/dev/null  || { echo >&2 "error: jq not found";  exit 3; }

. "${DIR}/lib.sh"

function usage() {
    cat <<END >&2
USAGE: $0 [-f creds_file] [-b bucket] [-g region] [-v|-h]
        -f file        # credentials JSON from assume-role.sh (default: ${DIR}/.creds.json)
        -b bucket      # bucket (default: terraform output bucket_name)
        -g region      # region (default: terraform output aws_region)
        -h|?           # usage
        -v             # verbose: show AWS CLI error output

Checks that the temporary credentials can use users/<sub>/ and nothing else.
Exits non-zero if any check fails.
END
    exit $1
}

declare CREDS_FILE="${DIR}/.creds.json"
declare BUCKET=''
declare REGION=''
declare opt_verbose=0

while getopts ":f:b:g:hv?" opt; do
    case ${opt} in
    f) CREDS_FILE=${OPTARG} ;;
    b) BUCKET=${OPTARG} ;;
    g) REGION=${OPTARG} ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    \?) [[ "${OPTARG}" == "?" ]] && usage 0
        echo >&2 "ERROR: illegal option -- ${OPTARG}"
        usage 1 ;;
    :) echo >&2 "ERROR: option requires an argument -- ${OPTARG}"; usage 1 ;;
    esac
done

[[ -z "${BUCKET}" ]] && BUCKET=$(tf_output bucket_name)
[[ -z "${REGION}" ]] && REGION=$(tf_output aws_region)

[[ -f "${CREDS_FILE}" ]] || { echo >&2 "ERROR: credentials file missing: ${CREDS_FILE} (run assume-role.sh first)"; usage 1; }
[[ -z "${BUCKET}" ]]     && { echo >&2 "ERROR: BUCKET undefined"; usage 1; }
[[ -z "${REGION}" ]]     && { echo >&2 "ERROR: REGION undefined"; usage 1; }

AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' "${CREDS_FILE}")
AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' "${CREDS_FILE}")
AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' "${CREDS_FILE}")
SUBJECT=$(jq -r '.Subject' "${CREDS_FILE}")
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
# Use only the temporary credentials above, never a local profile
export AWS_CONFIG_FILE=/dev/null AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_REGION="${REGION}" AWS_PAGER=''
readonly SUBJECT

declare -r OWN_PREFIX="users/${SUBJECT}/"
declare -r OTHER_PREFIX="users/someone-else/"
declare -r KEY="${OWN_PREFIX}hello-$(date +%s).txt"
declare -r OTHER_KEY="${OTHER_PREFIX}hello.txt"

tmp=$(mktemp -d)
readonly tmp
echo "hello from ${SUBJECT}" > "${tmp}/body.txt"

declare -i failures=0

# check <allow|deny> <description> <aws args...>
function check() {
    local expect=$1 description=$2
    shift 2
    local out rc=0
    out=$(aws "$@" 2>&1) || rc=$?

    local ok=0
    if [[ "${expect}" == "allow" && ${rc} -eq 0 ]]; then
        ok=1
    elif [[ "${expect}" == "deny" && ${rc} -ne 0 && "${out}" == *AccessDenied* ]]; then
        ok=1
    fi

    if [[ ${ok} -eq 1 ]]; then
        printf 'PASS  %-6s %s\n' "${expect}" "${description}"
    else
        printf 'FAIL  %-6s %s\n' "${expect}" "${description}"
        failures+=1
        out="${out//$'\n'/$'\n      '}"
        echo >&2 "      ${out}"
        return 0
    fi
    [[ ${opt_verbose} -eq 1 && -n "${out}" ]] && echo >&2 "      ${out//$'\n'/$'\n      '}"
    return 0
}

echo "subject: ${SUBJECT}"
echo "bucket:  ${BUCKET}"
echo

check allow "put    ${KEY}"                  s3api put-object --bucket "${BUCKET}" --key "${KEY}" --body "${tmp}/body.txt"
check allow "list   ${OWN_PREFIX}"           s3api list-objects-v2 --bucket "${BUCKET}" --prefix "${OWN_PREFIX}"
check allow "get    ${KEY}"                  s3api get-object --bucket "${BUCKET}" --key "${KEY}" "${tmp}/got.txt"
check deny  "list   bucket root (no prefix)" s3api list-objects-v2 --bucket "${BUCKET}"
check deny  "list   ${OTHER_PREFIX}"         s3api list-objects-v2 --bucket "${BUCKET}" --prefix "${OTHER_PREFIX}"
check deny  "put    ${OTHER_KEY}"            s3api put-object --bucket "${BUCKET}" --key "${OTHER_KEY}" --body "${tmp}/body.txt"
check deny  "get    ${OTHER_KEY}"            s3api get-object --bucket "${BUCKET}" --key "${OTHER_KEY}" "${tmp}/other.txt"

echo
if [[ ${failures} -eq 0 ]]; then
    echo "All checks passed."
else
    echo >&2 "${failures} check(s) failed."
    exit 1
fi
