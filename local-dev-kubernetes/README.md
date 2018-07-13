# Introduction

This example shows how to link a local development environment to a remote
staging environment, in order to develop a single microservice that may be
dependent on many other microservices. The goal is to only have to run a single
service (`pyservice`) locally, while proxying all other calls to an externally
maintained Kubernetes cluster.

The advantage of this approach is that minikube allows developers to run
whatever workflow they want locally. If developers using minikube already, the
addition to their cluster is lightweight. The only two additions to their setup
are an Envoy sidecar on the service under test, and a Rotor deployment/service
to provide configuration to the sidecar. These are configured by Houston, so
there is no need to update either configuration on a regular basis.

On the other side, this allows developers to hook into a central staging
environment with up-to-date versions of all services. Since the remote version
can be hosted anywhere, it can be a shared environment for multiple
developers. Typically, most developers will only need the latest version of
other services, so most organizations will not need more than one of these
shared staging environments.

Contrast this with [telepresence-houston](../telepresence-houston/README.md),
which uses a different setup to route traffic a shared staging environment to
your laptop, instead of routing traffic from your laptop to the shared staging
environment. One could combine both to get bidirectional routing!

# Architecture

This uses minikube as a local development environment. Minikube will run our
service under test. The dependencies will run in a remote Kubernetes cluster
that we share a network with (e.g. over a VPN).

Making a request looks like:

1. Using curl on our laptop to generate a request,
2. which is handled by the `pyservice1` service in minikube,
3. which routes to a `pyservice` pod in minikube,
4. which makes a request to a Houston-managed Envoy sidecar,
5. which routes the request to a Houston-managed Envoy on the remote cluster
6. which routes the request to the correct pod in the remote cluster.

![architecture.jpg](architecture.jpg)

(The author apologizes for their shoddy handwriting.)

# Deployment

## Minikube

To share a local registry between the docker daemon and minikube, set these
environment variables:

```
eval $(minikube docker-env)
```

First, build `pyservice`, the Python service we're developing. No need to push
it anywhere remote -- Minikube will be able to pick up the image.

```
docker build -f Dockerfile-service -t pyservice1:1.0.0 .
```

Next, we'll deploy Rotor onto minikube, which will eventually configure our
Envoy sidecar. Note: you'll have to have a Turbine Labs AccessToken stored as a
Kubernetes secret in your minikube for this to work. See
[the Turbine Labs Kubernetes Guide](https://docs.turbinelabs.io/advanced/kubernetes.html)
for instructions on setting this up.

```
kubectl create -f minikube-rotor.yaml
```

Then, let's set up `pyservice` as a deployment and service. This has an Envoy
sidecar based on [envoy-simple](https://github.com/turbinelabs/envoy-simple),
and it's configured to read all its config from the Rotor we just deployed.

```
kubectl create -f minikube-service.yaml
```

There are two endpoints available in `pyservice`. `/service/1` just echoes back
the current configuration:

```
 $ curl $(minikube service pyservice --url)/service/1
Hello from minikube (service 1)! hostname: pyservice-7d96498669-4chm2 resolvedhostname: 172.17.0.4
```

`/trace/1` makes a call to `demo.turbinelabs.io` through the sidecar Envoy. This
doesn't work quite as well:

```
$ curl $(minikube service pyservice1 --url)/trace/1
Hello from minikube -- upstream connect error or disconnect/reset before headers (service 1)! hostname: pyservice1-7d96498669-4chm2 resolvedhostname: 172.17.0.4
```

At this point, our Envoy is confused, because there's no configuration coming
down from Houston. We'll fix that in a later step, but first lets set up the
remote cluster.

## Remote Cluster

First, make sure you've set up a
[front proxy with Houston](https://docs.turbinelabs.io/advanced/kubernetes.html).
This will set up a zone called `testbed` with all your Kubernetes services, and
we'll re-use this configuration.

Beyond that, there are two things to set up in the remote cluster:

1. An Envoy, deployed using `hostNetwork: true` and `dnsPolicy:
   ClusterFirstWithHostNet`, so the pods are directly exposed on the host
   network.
2. A Rotor instance, to collect the IP of the exposed Envoy, for the local
   clusters.

You can create the necessary objects for this with:

```
kubectl create -f staging.yaml
```

## Houston

At this point, we have all the information needed to configure the Envoys in our
minikube environment, so we'll do that in the app.

First, create a new zone called `dev-local`

```
tbnctl init-zone dev-local
```

Within the UI, you'll need to create several objects in the `dev-local`
zone:

1. A proxy named `dev-proxy`
2. A domain named `demo.turbinelabs.io` on port `8888`, linked to the
   `dev-proxy` proxy.
3. A route group (`default` is a fine name).
4. A route on `/api` for `demo.turbinelabs.io`, in the `default` route group,
   that sends traffic to the `envoy-simple` service.

At this point, you'll want to customize the domains and routes to set up. For
example, our staging environment contains a service at `demo.turbinelabs.io/api`
that returns a hex color
([this container](https://hub.docker.com/r/turbinelabs/all-in-one/)).

Repeat steps 2-4 for any other routes you want Envoy to serve. All of them
should go to the `envoy-simple` service -- it's just the IP of one of the nodes
in your Kubernetes cluster. If that pod gets rescheduled, that's fine! The Rotor
we deployed will notice the change and automatically update Envoy in minikube.

Once that's set up, you can see [`service.py`](service.py) return the color from
the remote service.

```
$ curl $(minikube service pyservice1 --url)/trace/1
Hello from minikube -- 00ff00 (service 1)! hostname: pyservice1-7d96498669-4chm2 resolvedhostname: 172.17.0.4
```

That's it! Local development + shared staging services!

# Other Architectures

This setup is entirely reliant on Envoy and a shared networking environment, so
switching out minikube for docker-compose or local processes is possible. Here's
some considerations:

 - **docker** Since Docker doesn't natively come with the idea of pods, the
   trick is to get the networking right. The easiest way to do this is probably
   to simple provide your devs with a docker container based on `envoy-simple`
   that sets the environment variables to point to your Houston instance. As
   long as devs are comfortable setting up their local containers to talk to an
   Envoy container, everything should work the same.
 - **docker-compose** This is probably the closest to minikube, as adding Envoy
   to a service's `docker-compose.yaml` works roughly like a pod.
 - **OS process** In this case, devs can run a single Houston-managed Envoy on
   their OS and have their services point to localhost, just like it would in a
   staging / production deployment.
