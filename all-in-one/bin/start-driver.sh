#!/usr/bin/env bash

if [[ -n "$ALL_IN_ONE_DRIVER" ]]; then
  echo "Driver: waiting for services to start up"
  sleep 10
  /usr/local/bin/all-in-one-driver
fi
