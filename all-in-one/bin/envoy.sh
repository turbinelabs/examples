#!/bin/bash

source /usr/local/bin/envcheck.sh

# Convert TBNPROXY-style environment variables.
if [ -z "$ALL_IN_ONE_NODE" ]; then
    export ALL_IN_ONE_NODE="${TBNPROXY_STATS_NODE:-all-in-one}"
fi

if [ -z "$ALL_IN_ONE_PROXY_NAME" ]; then
  if [ -n "$TBNPROXY_PROXY_NAME" ]; then
    export ALL_IN_ONE_PROXY_NAME="$TBNPROXY_PROXY_NAME"
    echo "info: converted TBNPROXY_PROXY_NAME to ALL_IN_ONE_PROXY_NAME"
  fi
fi

if [ -z "$ALL_IN_ONE_API_ZONE_NAME" ]; then
    if [ -n "$TBNPROXY_API_ZONE_NAME" ]; then
      export ALL_IN_ONE_API_ZONE_NAME="$TBNPROXY_API_ZONE_NAME"
      echo "info: converted TBNPROXY_API_ZONE_NAME to ALL_IN_ONE_API_ZONE_NAME"
    fi
fi

require_vars ALL_IN_ONE_NODE \
             ALL_IN_ONE_PROXY_NAME \
             ALL_IN_ONE_API_ZONE_NAME

export ENVOY_NODE_ID="$ALL_IN_ONE_NODE"
export ENVOY_NODE_CLUSTER="$ALL_IN_ONE_PROXY_NAME"
export ENVOY_NODE_ZONE="$ALL_IN_ONE_API_ZONE_NAME"

/usr/local/bin/start-envoy.sh
