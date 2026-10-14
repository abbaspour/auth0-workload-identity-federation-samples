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
USAGE: $0 [-m curl|cli] [-f token_file | -t token] [-r role_arn] [-g region] [-n session_name] [-v|-h]
        -m mode          # curl (STS HTTPS API, default) or cli (aws sts assume-role-with-web-identity)
        -f file          # file holding the Auth0 access token, or - for stdin (default: ${DIR}/.token)
        -t token         # access token on the command line
        -r role_arn      # role to assume (default: terraform output role_arn)
        -g region        # STS region (default: terraform output aws_region)
        -n session_name  # role session name (default: wif-demo)
        -h|?             # usage
        -v               # verbose: print the token's claims to stderr

Prints normalized temporary credentials as JSON on stdout.
The call is unsigned: no AWS credentials or profile are needed.

eg,
     $0 -m curl > ${DIR}/.creds.json
END
    exit $1
}

declare MODE='curl'
declare TOKEN_FILE="${DIR}/.token"
declare TOKEN=''
declare ROLE_ARN=''
declare REGION=''
declare SESSION_NAME='wif-demo'
declare opt_verbose=0

while getopts ":m:f:t:r:g:n:hv?" opt; do
    case ${opt} in
    m) MODE=${OPTARG} ;;
    f) TOKEN_FILE=${OPTARG} ;;
    t) TOKEN=${OPTARG} ;;
    r) ROLE_ARN=${OPTARG} ;;
    g) REGION=${OPTARG} ;;
    n) SESSION_NAME=${OPTARG} ;;
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

[[ -z "${ROLE_ARN}" ]] && ROLE_ARN=$(tf_output role_arn)
[[ -z "${REGION}" ]]   && REGION=$(tf_output aws_region)

[[ -z "${TOKEN}" ]]    && { echo >&2 "ERROR: TOKEN empty";        usage 1; }
[[ -z "${ROLE_ARN}" ]] && { echo >&2 "ERROR: ROLE_ARN undefined"; usage 1; }
[[ -z "${REGION}" ]]   && { echo >&2 "ERROR: REGION undefined";   usage 1; }
[[ "${MODE}" == "curl" || "${MODE}" == "cli" ]] || { echo >&2 "ERROR: MODE must be curl or cli"; usage 1; }

[[ ${opt_verbose} -eq 1 ]] && jwt_claims "${TOKEN}" >&2

# Both modes yield: {Credentials:{AccessKeyId,SecretAccessKey,SessionToken,Expiration}, Subject, Audience, AssumedRoleArn}
if [[ "${MODE}" == "curl" ]]; then
    response=$(curl -s --request POST \
        --header 'accept: application/json' \
        --data-urlencode 'Action=AssumeRoleWithWebIdentity' \
        --data-urlencode 'Version=2011-06-15' \
        --data-urlencode "RoleArn=${ROLE_ARN}" \
        --data-urlencode "RoleSessionName=${SESSION_NAME}" \
        --data-urlencode "WebIdentityToken=${TOKEN}" \
        --url "https://sts.${REGION}.amazonaws.com/")
    result=$(jq -c '.AssumeRoleWithWebIdentityResponse.AssumeRoleWithWebIdentityResult // empty' <<< "${response}" 2>/dev/null || true)
else
    command -v aws >/dev/null || { echo >&2 "error: aws not found"; exit 3; }
    # Unsigned request; ignore any local profile/config so nothing but the token is used.
    response=$(AWS_CONFIG_FILE=/dev/null AWS_SHARED_CREDENTIALS_FILE=/dev/null aws sts assume-role-with-web-identity \
        --no-sign-request --region "${REGION}" --output json \
        --role-arn "${ROLE_ARN}" --role-session-name "${SESSION_NAME}" \
        --web-identity-token "${TOKEN}" 2>&1) || true
    result=$(jq -c 'select(.Credentials) | {Credentials, SubjectFromWebIdentityToken, Audience, AssumedRoleUser}' <<< "${response}" 2>/dev/null || true)
fi

[[ -n "${result}" ]] || { echo >&2 "ERROR: AssumeRoleWithWebIdentity failed:"; echo >&2 "${response}"; exit 1; }

jq '{Credentials: {AccessKeyId: .Credentials.AccessKeyId, SecretAccessKey: .Credentials.SecretAccessKey, SessionToken: .Credentials.SessionToken, Expiration: .Credentials.Expiration},
     Subject: .SubjectFromWebIdentityToken, Audience: .Audience, AssumedRoleArn: .AssumedRoleUser.Arn}' <<< "${result}"
