#!/usr/bin/env bash

set -e

if [[ -z $ALL_IN_ONE_CLIENT_PORT ]]; then
  ALL_IN_ONE_CLIENT_PORT=8080
fi

if [[ -z $ALL_IN_ONE_CLIENT_DIR ]]; then
  ALL_IN_ONE_CLIENT_DIR=.
fi

FILE=${ALL_IN_ONE_CLIENT_DIR}/create-workers.js
envtemplate -in $FILE -out $FILE && http-server ${ALL_IN_ONE_CLIENT_DIR} -p $ALL_IN_ONE_CLIENT_PORT
