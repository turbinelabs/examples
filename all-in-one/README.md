# Overview

All-in-one is a single docker image that lets you run a full demo of
[Houston](https://turbinelabs.io/product) in a self contained, easy to approach
manner. This container runs:

- 1x static NGINX to host demo app client
- 3x demo app servers, one each yellow, blue, green
- [envoy-simple](https://github.com/turbinelabs/envoy-simple)
- [Rotor](https://github.com/turbinelabs/rotor) in file mode

# Prerequisites

In order to use this guide, you’ll need:

 - Go 1.10.3 or later (previous versions may work, but we don't build or test
   against them)
 - Docker
 - A [Houston account](https://turbinelabs.io/contact)

To get your Houston access token (used below on startup), run:

```
curl https://docs.turbinelabs.io/introduction/examples/setup_tbn.sh | bash -s all-in-one
```

Store this token somewhere safe, as it won't be displayed again.

# Operation

It relies on the following environment variables:

Variable                   | Meaning
-------------------------- | -------
`ALL_IN_ONE_API_KEY`       | the Turbine Labs API key to use
`ALL_IN_ONE_API_ZONE_NAME` | the Turbine Labs zone name
`ALL_IN_ONE_PROXY_NAME`    | the name of the proxy, usually the zone name with a `-proxy` suffix

An example of container startup is

```
docker run -p 80:80 \
    -e "ALL_IN_ONE_API_KEY=$TBN_API_KEY" \
    -e "ALL_IN_ONE_API_ZONE_NAME=all-in-one" \
    -e "ALL_IN_ONE_PROXY_NAME=all-in-one-proxy" \
    turbinelabs/all-in-one:0.18.2
```

The container is now serving the domain `all-in-one` on localhost. Add the
following line to `/etc/hosts` to get to it from your browser:

```
127.0.0.1   all-in-one
```

At this point you should be able to point a browser to
[https://all-in-one-demo](https://all-in-one-demo) whatever domain you set up in
Houston and see the demo app. You can use [Houston](https://app.turbinelabs.io)
to edit API routes and view stats.

(Note that you need the `/etc/hosts/` change because Envoy requires a host
header to route. Simplying going to `localhost` doesn't set a domain that Envoy
knows about, so it returns a 404.)

If you've made changes to Routes, SharedRules, or Proxies that you want to
roll back, you can add `-e "ALL_IN_ONE_INIT_ZONE_REPLACE=true"` to the command
above.

## Latency and Error Rates

By default, each of the demo servers returns a successful (status code 200)
response with its color (as a hex string) as the response body.

Each demo server is configured with a name, matching its
color: blue, green, or yellow.

URL parameters passed to the web page at http://localhost can be used
to control the mean latency and error rate of each of the different
server colors. The parameters are of the form:

Parameter        | Effect
---------------- | ------
 x-`color`-delay | Sets the mean delay in milliseconds.
 x-`color`-error | Sets the error rate, describe as a fraction of 1 (e.g., 0.5 causes an error 50% of the time).

The latency and error rates are passed to the demo servers as HTTP headers with
the same name and value as the URL parameters described.

## Headless traffic driver

If you want a steady source of traffic apart from the browser, you can add this to your docker run invocation:

```
    -e ALL_IN_ONE_DRIVER=1 \
```

You can specify target error rates and latencies as well:

```
    -e ALL_IN_ONE_DRIVER_LATENCIES=blue:10ms,green:25ms \
    -e ALL_IN_ONE_DRIVER_ERROR_RATES=blue:0.01,green:0.005 \
```

# Implementation

On startup the container does the following using phusion's `/etc/my_init.d` system:

- Runs a script to verify that the docker container's current time is correct.
- Runs `tbnctl` to set up default zones and routes. The specific command is:

```
tbnctl --api.key="$ALL_IN_ONE_API_KEY" init-zone \
    --routes="all-in-one-demo:80=all-in-one-client" \
    --routes="all-in-one-demo:80/api=all-in-one-server:stage=prod:version=blue" \
    --proxies="$ALL_IN_ONE_PROXY_NAME=all-in-one-demo:80" \
    $ALL_IN_ONE_API_ZONE_NAME
```

- Creates a proxy entry in that zone, serving the newly created domain.

It then uses phusion's service mechanism to start Envoy, Rotor,
all-in-one servers, and the all-in-one client.

```
docker run -p 80:80 \
    -e "ALL_IN_ONE_API_KEY=$TBN_API_KEY" \
    -e "ALL_IN_ONE_API_ZONE_NAME=all-in-one-demo-1" \
    -e "ALL_IN_ONE_PROXY_NAME=all-in-one-demo-1-proxy-1" \
    turbinelabs/all-in-one:0.18.2
```
