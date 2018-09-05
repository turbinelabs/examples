#!/usr/bin/env bash

source /usr/local/bin/envcheck.sh

rewrite_vars TBNPROXY_   ROTOR_
rewrite_vars TBNCOLLECT_ ROTOR_
rewrite_vars ALL_IN_ONE_ ROTOR_

require_vars ROTOR_API_KEY \
             ROTOR_API_ZONE_NAME

export ROTOR_CMD="file"
export ROTOR_FILE_FORMAT="yaml"
export ROTOR_FILE_FILENAME=/opt/rotor/clusters.yml

/usr/local/bin/rotor.sh
