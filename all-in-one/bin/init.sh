#!/usr/bin/env bash

source /usr/local/bin/envcheck.sh

rewrite_vars TBNPROXY_   TBNCTL_
rewrite_vars ALL_IN_ONE_ TBNCTL_

require_vars TBNCTL_API_KEY \
             TBNCTL_API_ZONE_NAME \
             TBNCTL_PROXY_NAME

tbnctl --console.level=debug init-zone \
    --domains="all-in-one-demo:80=localhost:127.0.0.1" \
    --routes="all-in-one-demo:80=all-in-one-client" \
    --routes="all-in-one-demo:80/api=all-in-one-server:stage=prod:version=blue" \
    --proxies="$TBNCTL_PROXY_NAME=all-in-one-demo:80" \
    $TBNCTL_API_ZONE_NAME
