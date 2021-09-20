#!/bin/bash

urlencode() {
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%s' "$c" | xxd -p -c1 |
                   while read c; do printf '%%%s' "$c"; done ;;
        esac
    done
}

urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

set -e

if [ -z "$webhook_url" ]; then
    echo "No webhook_url configured"
    exit 1
fi

if [ -z "$webhook_secret" ]; then
    echo "No webhook_secret configured"
    exit 1
fi

REQUEST_ID=$(uuidgen)
EVENT=`urlencode "$GITHUB_EVENT_NAME"`
REPOSITORY=`urlencode "$GITHUB_REPOSITORY"`
COMMIT=`urlencode "$GITHUB_SHA"`
REF=`urlencode "$GITHUB_REF"`
HEAD=`urlencode "$GITHUB_HEAD_REF"`
WORKFLOW=`urlencode "$GITHUB_WORKFLOW"`

CONTENT_TYPE="application/x-www-form-urlencoded"
WEBHOOK_DATA="event=$EVENT&repository=$REPOSITORY&commit=$COMMIT&ref=$REF&head=$HEAD&workflow=$WORKFLOW&requestID=$REQUEST_ID"

if [ -n "$data" ]; then
    WEBHOOK_DATA="${WEBHOOK_DATA}&${data}"
fi

WEBHOOK_SIGNATURE=$(echo -n "$WEBHOOK_DATA" | openssl sha1 -hmac "$webhook_secret" -binary | xxd -p)
WEBHOOK_SIGNATURE_256=$(echo -n "$WEBHOOK_DATA" | openssl dgst -sha256 -hmac "$webhook_secret" -binary | xxd -p |tr -d '\n')
WEBHOOK_ENDPOINT=$webhook_url

options="--http1.1 --fail"

curl $options \
    -H "Content-Type: $CONTENT_TYPE" \
    -H "User-Agent: GitHub-Hookshot/$GITHUB_REPOSITORY" \
    -H "X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE" \
    -H "X-Hub-Signature-256: sha256=$WEBHOOK_SIGNATURE_256" \
    -H "X-GitHub-Delivery: $GITHUB_RUN_NUMBER" \
    -H "X-GitHub-Event: $GITHUB_EVENT_NAME" \
    --data "$WEBHOOK_DATA" $WEBHOOK_ENDPOINT
