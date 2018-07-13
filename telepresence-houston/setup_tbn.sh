#!/bin/bash -e
#
# Copyright 2018 Turbine Labs, Inc.
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.

# Install tbnctl
go get -u github.com/turbinelabs/tbnctl
go install github.com/turbinelabs/tbnctl

# Login (interactive)
echo Log in with your Houston password:
tbnctl login

# Set up some objects
tbnctl init-zone local-dev
echo using zone local-dev
zone_key=$(tbnctl list zone | grep -B1 '"local-dev"' | grep zone_key | cut -d '"' -f 4)

has_proxy=$(tbnctl list proxy zone_key=$zone_key | grep local-dev || true)
if [ -z "$has_proxy" ]
then
    proxy_json="{\"zone_key\": \"$zone_key\", \"name\": \"local-dev-proxy\"}"
    echo $proxy_json | tbnctl create proxy
    echo created proxy local-dev-proxy
else
    echo local-dev-proxy proxy already exists
fi

# Look for an access token
tbnctl access-tokens add "setup_tbnctl.sh key"
echo created new access token \"setup_tbnctl.sh key\":
