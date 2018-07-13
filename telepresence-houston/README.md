# telepresence-houston

This example combines [Houston](https://turbinelabs.io/product) and
[Telepresence](telepresence.io) to allow developers to route requests from a
shared staging environment to code running on their local laptop.

We'll set up a simple microservices-based application and walk through the steps
necessary to run the backend service locally, without impacting other developers
using the remote cluster. Here's a GIF of the end goal:

- It starts with the browser on the right connected to a shared environment,
  running the code on a laptop shown on the left. It is returning green.
- We modify the code and restart my local process. This kills all requests, so
  the client shows red.
- When the local process comes back up with the modified code, the browser
  starts returning the new color, purple.

![fast dev workflow with Houston, Kubernetes, and Telepresence](dev-workflow.gif)

Contrast this with [local-dev-kubernetes](../local-dev-kubernetes/README.md),
which uses a different setup to route traffic from your laptop to the shared
staging environment, instead of routing traffic from the shared staging
environment to your laptop. One could combine both to get bidirectional routing!

# Setting Up The Shared Staging Environment

To deploy all this, you'll need:

 - Go 1.10.1 or later (previous versions may work, but we don't build or test
   against them)
 - A Houston access token ([Sign up here](https://www.turbinelabs.io/contact))
 - A Kubernetes environment

The app we'll use consists of 2 microservices, deployed in Kubernetes:

 - Our frontend, the
   [Turbine Labs' all-in-one client](https://github.com/turbinelabs/all-in-one/tree/master/client),
   which returns a single HTML page.
 - Our backend, the
   [Turbine Labs' all-in-one server](https://github.com/turbinelabs/all-in-one/tree/master/server),
   which returns a simple hex color.

We'll serve the client on `demo.example.com` and the server on
`demo.example.com/api`, using an Envoy front proxy, configured by
Houston.

To generate an access token, run the setup script. Take the value of the
generated token and store it as a secret in Kubernetes.

```
bash setup_tbn.sh # This sets up a zone called local-dev
kubectl create secret generic tbnsecret --from-literal=apikey=<value of signed_token>
```

We have 4 deployments. Envoy is exposed as a LoadBalancer Service, and Rotor is
exposed as a normal Service. You can create them from the YAML in this
directory:

```
kubectl create -f rotor.yaml
kubectl create -f envoy.yaml
kubectl create -f all-in-one-server.yaml
kubectl create -f all-in-one-client.yaml
kubectl expose deployment envoy --type=LoadBalancer
```

Finally, we need one deployment that we'll take over with Telepresence:

```
kubectl apply -f all-in-one-server-dev.yaml
```

# Setting Up Routing Rules In Houston

Though all our services are deployed in Kubernetes, Envoy isn't serving anything
yet. We'll configure routing rules in Houston to expose it.

To set up routes through the API, run:

```
tbnctl init-zone \
    --routes="demo.example.com:80=all-in-one-client" \
    --routes="demo.example.com:80/api=all-in-one-server:stage=prod:version=master" \
    --proxies="local-dev-proxy=demo.example.com:80" \
    local-dev
```

These rules make sure that traffic goes to the `master` version of the code --
this label is attached to the deployment from `all-in-one-server.yaml`. To route
requests to our local version, we'll set up a rule that allows us to request
specific clusters via a header. Go to
[the all-in-one-server route group in the app](https://app.turbinelabs.io/edit/local-dev/route-group/all-in-one-server)
and add a rule that routes requests with an `X-Tbn-Version` header to the cluster
set in the header. Click "

![A screenshot of the override header configuration](override.png)

To test all this, you'll need to either set up DNS for demo.example.com or
add an entry to your `/etc/hosts` file. Either way, find the IP of your Envoy
instance with:

```
kubectl get services
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP          13d
envoy        NodePort    10.101.158.24    18.1.2.3      80:32730/TCP     12d
rotor        ClusterIP   10.100.134.176   <none>        50000/TCP        12d
```

In this case, look for the `EXTERNAL-IP` `18.1.2.3` and add the following line
to your `/etc/hosts`:

```
18.1.2.3  demo.example.com
```

You can test that this worked by going to `demo.example.com` in your
browser. If it's working, you should see blue squares:

![blue blinky lights](blocks.png)

If you add a header, you can see the placeholder dev version at
[demo.example.com?x-tbn-version=my-local-copy](https://demo.example.com?x-tbn-version=my-local-copy),
which returns orange.

# Setting Up Your Local Environment

Now, let's use Telepresence to run the dev version on our laptop instead of the
remote cluster. This will let us make quick modifications to our code without
having to build an image, push it to a Docker registry, and re-deploy it in
Kubernetes.

The app we're developing is a single node.js file. You'll need to be able to run
this locally, so first install its dependencies:

```
# Make sure you have node.js 8.4 installed
# (May work with later versions, but we don't test against them)
# brew install node@8.4 # OS X
cd ../all-in-one/server
yarn install
node main.js
```

Let's go ahead and change the color it's serving. On line 18 in
[`examples/all-in-one/server/server.js`](https://github.com/turbinelabs/all-in-one/tree/master/server/server.js),
change the default color `'FFFAC3'` to another hex color. Since the environment
variables will be inherited from the Kubernetes environment, you'll want to
remove `process.env.TBN_COLOR` bit, too. Maybe you'd like bright green?

```diff
- let bodyColor = (process.env.TBN_COLOR || 'FFFAC3') + '\n'
+ let bodyColor = ('00FF00') + '\n'
```

Then run the program and and expose it via telepresence
([installation instructions](https://www.telepresence.io/reference/install)):

```
# Installation on OS X
# brew cask install osxfuse
# brew install socat datawire/blackbird/telepresence
telepresence --swap-deployment all-in-one-server-dev --expose 8080   --run node all-in-one-server/main.js
```

You can now visit
[demo.example.com?x-tbn-version=dev](https://demo.example.com?x-tbn-version=dev),
and see your new color running. As you develop, just restart this process, and
you can make your changes visible to the cluster.

# Other Considerations

Depending on your computer and you internet connection, you may see red blocks
in this demo, too. This means the requests have timed out. This is generally due
to the number of requests in this particular demo saturating the network over
telepresence. Your mileage may vary with a high volume of requests in this
particular setup.

If you're thinking ahead, you'll need one telepresence deployment for each
service and each developer. This approach should work for a team of 50
developers, but you'll need 50-200 deployments total that they can telepresence
into.
