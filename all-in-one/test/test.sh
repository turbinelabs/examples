#!/bin/bash

NAME=all-in-one-test-$RANDOM
IMAGE=${ALL_IN_ONE_IMAGE:-all-in-one}
VERSION=${ALL_IN_ONE_VERSION:-latest}
MAX_ATTEMPTS=10

export TERM="${TERM:-dumb}"
if [ "${TERM}" = "dumb" -a "${CIRCLECI}" = "true" ]; then
    export TERM=ansi
fi

YELLOW="$(tput setaf 3)"
RESET="$(tput sgr0)"

set -e -o pipefail

function report {
    local MSG="$1"
    echo "${YELLOW}${MSG}${RESET}"
}

function report_indent {
    local INDENT="$1"
    local MSG="$2"
    echo -n "${YELLOW}"
    echo "$MSG" | sed -e "s/^/${INDENT}/; s/\\r//g"
    echo -n "${RESET}"
}

function cleanup {
  RET=$?
  report "killing docker container ${NAME}"
  docker kill "${NAME}"
  exit $RET
}

report "******** testing $IMAGE:$VERSION"

function retry {
  NOTE=$1
  CMD=$2
  EXPR=$3
  ATTEMPT=0

  until [[ $ATTEMPT -eq MAX_ATTEMPTS ]]; do
    report "attempt $((ATTEMPT+1)) of $MAX_ATTEMPTS: $NOTE"

    set +e
    # eval because it has the pipes
    RESULT=$(eval $CMD)
    CODE=$?
    set -e

    if [[ $CODE == 0 ]]; then
      # if there's an expression, test for non-empty result
      if [[ -n $EXPR ]]; then
        if [[ $RESULT =~ $EXPR ]]; then
          report_indent "  " "$RESULT"
          return
        fi
      # otherwise, any result is fine as long as the code is good
      else
        report "  success!"
        return
      fi
    fi

    sleep 5
    ATTEMPT=$((ATTEMPT + 1))
  done
  report "failed after $MAX_ATTEMPTS tries: $NOTE"
  exit 1
}

# test for $TBN_API_KEY
if [[ -z $TBN_API_KEY ]]; then
  report "\$TBN_API_KEY must be set"
  exit 1
fi

retry \
  "checking to make sure API is up" \
  "curl -s -I -X GET -H 'Authorization: Token $TBN_API_KEY' https://api.turbinelabs.io/v1.0/cluster" \
  "200 OK"

report "starting container $NAME"

docker run \
  --name=$NAME \
  --rm \
  -e "TBNPROXY_API_KEY=$TBN_API_KEY" \
  -e "TBNPROXY_API_ZONE_NAME=build-test-zone" \
  -e "TBNPROXY_PROXY_NAME=build-test-proxy" \
  turbinelabs/$IMAGE:$VERSION&

# cleanup docker container on exit
trap cleanup INT EXIT

retry \
  "waiting for $NAME container to start" \
  "docker ps | grep $NAME"

retry \
  "waiting for all-in-one envoy listeners" \
  "docker exec $NAME curl -s -X GET -m 1 http://localhost:9999/listeners" \
  "0.0.0.0:80"

retry \
  "testing client" \
  "docker exec $NAME curl -s -I -H 'Host: all-in-one-demo' -X GET -m 1 http://localhost" \
  "200 OK"

retry \
  "testing server" \
  "docker exec $NAME curl -s -I -H 'Host: all-in-one-demo' -X GET -m 1 http://localhost/api" \
  "200 OK"

report "success!"
