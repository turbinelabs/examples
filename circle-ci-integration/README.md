[//]: # ( Copyright 2018 Turbine Labs, Inc.                                   )
[//]: # ( you may not use this file except in compliance with the License.    )
[//]: # ( You may obtain a copy of the License at                             )
[//]: # (                                                                     )
[//]: # (     http://www.apache.org/licenses/LICENSE-2.0                      )
[//]: # (                                                                     )
[//]: # ( Unless required by applicable law or agreed to in writing, software )
[//]: # ( distributed under the License is distributed on an "AS IS" BASIS,   )
[//]: # ( WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or     )
[//]: # ( implied. See the License for the specific language governing        )
[//]: # ( permissions and limitations under the License.                      )

# Houston Integration with CircleCI and GKE

[![Apache 2.0](https://img.shields.io/badge/license-apache%202.0-blue.svg)](LICENSE)

_**NOTE**: This example has gone a little stale. We hope to bring it up to speed
sometime soon._

This project demonstrates how to utilize
[GKE](https://cloud.google.com/container-engine/),
[CircleCI](https://circleci.com/),
and [Houston](http://go.turbinelabs.io/release/) to build a developer friendly,
yet manageable continuous release pipeline. With our setup developers can have
their branches automatically built and deployed on a Kubernetes cluster. They'll
be hidden from live customers, but accessible to users who specifically request
these versions. Developers can also push a tag to github that triggers a
production deployment. This deployment is initially hidden from live customers
as well, but using the Houston UI you can gradually shift traffic from your
existing version to the newly deployed one.

# Before You Start

You'll need a GKE account, CircleCI account, and a Houston API key. This guide
builds on the Houston
[Kubernetes guide](https://docs.turbinelabs.io/guides/kubernetes.html),
which you should complete before working through this guide.

You should be able to run `kubectl get pods` and see something like the
following.

```console
> kubectl get pods
NAME                                                         READY     STATUS    RESTARTS   AGE
all-in-one-client-4074232872-qpx2x                           1/1       Running   0          20d
all-in-one-server-4292877153-6p992                           1/1       Running   0          101d
rotor-2527159180-cf2ts                                       1/1       Running   1          35d
tbnproxy-299795818-txbkv                                     1/1       Running   1          35d
```

If your kubectl instance is pointing somewhere else, you can run

`gcloud container clusters get-credentials <cluster name> --zone <compute zone> --project <project id>`

To fetch credentials, add them to `~/.kube/config`. Now find the public IP of the
tbnproxy for your running all-in-one service by running
`kubectl get service tbnproxy`.

```console
> kubectl get service tbnproxy
NAME       CLUSTER-IP     EXTERNAL-IP       PORT(S)        AGE
tbnproxy   10.7.243.188   104.196.242.214   80:31557/TCP   105d
```

Point to the external-ip with a web browser, and ensure the blinking boxes appear.

# Getting CircleCI Set Up

The [CircleCI With Google Container Engine Guide](https://circleci.com/docs/continuous-deployment-with-google-container-engine/),
is a good intro, but follows the typical first approach to managing releases in
Kubernetes. It patches a deployment, which means that code is immediately
release to all customers as long as health checks pass. We can do better.

Fork this repo, and add it as a CircleCI project. The only items should need to
configure are environment variables for your project.  Note that because we're
mapping git branches to Kubernetes labels you must use branch names that are
valid label values, which means no slashes or other characters that would
invalidate a Kubernetes label.

While the CircleCI example includes environment variables in config.yml, we'll
add them as project environment variables. You'll need to set
1. `GCLOUD_CLUSTER_NAME` – which can be found with `gcloud container
   clusters list`
2. `GCLOUD_COMPUTE_ZONE` – which can also be found with `gcloud container
   clusters list`
3. `GCLOUD_PROJECT ID` – described [here](https://console.cloud.google.com/home/dashboard)
4. `GOOGLE_AUTH` – described [here](https://circleci.com/docs/2.0/google-container-engine/#generating-a-service-account-key)

# Working With CI

The server app we'll use is located in the server directory. It's a simple node
app that returns a hex color as its response body for any request it gets. There
are very simple unit tests using Mocha. You can go to the server directory, and
run

```
npm install
npm test
```

to try it out. Make a change. Change the hex color on line 4 of server.js to a
lovely shade of whatever color you feel right now (we'll use #ffc0cb for the
remainder of this demo and push it to origin. Circle should check out code, run
the tests, and report success.

This is defined as a job in config.yaml as

```
jobs:
  build:
    docker:
      - image: node:8.4.0
    environment:
      DEBIAN_FRONTEND: noninteractive
    steps:
      - checkout
      - run: cd server && npm install && npm test
```

It's run as a workflow on every branch push that isn't named like
`/server-dev-.*/`

```
workflows:
  version: 2
  build:
    jobs:
      - build:
          filters:
            branches:
              ignore:
                - /server-dev-.*/
```

# Onwards to CD

The D in delivery is ambiguous, meaning either delivery or deployment. We'll do
both, delivering packages to
the [Google Container Registry](https://cloud.google.com/container-registry/),
and deploying to GKE.

Delivering and/or deploying every commit can quickly pollute your systems, so we
want some filter on what goes
out. CircleCI [workflows](https://circleci.com/docs/2.0/workflows/) allow us to
execute tasks based on branch or tag names.

## The gcloud build base image

The CircleCI examples use an image that installs the GCloud SDK from the
internet on each build run. We've created a build image here that has the GCloud
SDK installed, and just configures project/auth settings on each start. This
saves a significant amount of time on each build. The source for this image can
be found [on github](https://github.com/turbinelabs/gcloud-build), and we
publish images
to [dockerhub](https://hub.docker.com/r/turbinelabs/gcloud-build/).

## Delivery

The delivery task uses the gcloud-build image, checks out code, builds a
docker image from our source, and pushes it to GCR.

```
  push-dev-server:
    docker:
      - image: turbinelabs/gcloud-build:0.18.1
    environment:
      DEBIAN_FRONTEND: noninteractive
    steps:
      - checkout
      - setup_remote_docker
      - run: openrc boot
      - run: docker build -t gcr.io/${GCLOUD_PROJECT_ID}/all-in-one-server:$CIRCLE_BRANCH server
      - run: docker tag gcr.io/${GCLOUD_PROJECT_ID}/all-in-one-server:$CIRCLE_BRANCH gcr.io/${GCLOUD_PROJECT_ID}/all-in-one-server:la
      - run: gcloud docker -- push gcr.io/${GCLOUD_PROJECT_ID}/all-in-one-server:$CIRCLE_BRANCH
```

## Deploy

The deploy task also uses the gcloud-build image. It checks out code, but
instead of building and pushing code to gcr, it creates a kubectl spec for the
image we pushed in the delivery phase, and creates a new deployment on your GKE
cluster.

```
  deploy-dev-server:
    docker:
      - image: turbinelabs/gcloud-build:0.18.1
    steps:
      - checkout
      - run: openrc boot
      - run: ./deploy.sh dev server/dev-deploy-template.yaml
```

Deploy.sh is a simple shell script that pulls environment variables from the
CircleCI build and does rudimentary template application to a Kubernetes
deployment spec. It then calls `kubectl create` or `kubectl replace` to create
or update a deployment.

In the developer case, we update a deployment if one already exists. This allows
developers to iterate on a branch without polluting the Kubernetes cluster with
redundant deployments.

In the production case this is _not_ patching an existing deploy -- a completely
new deployment is created, allowing us to route traffic in a fine grained
fashion to our new pods.

## Managing CD

Pushing and deploying every commit can quickly pollute the container registry
and the Kubernetes cluster. CircleCI workflows allow you to filter on branches
and tags. The strategy encoded in this project allows developers to deploy
branches when they like by naming a branch according to the convention
`server-dev-<descriptive name>`. Those deploys are labeled with a stage of
"dev". Houston observes this label and ensures that they don't receive
production traffic. The workflow runs tests, executes the docker build and push,
and then creates a new deployment.

```
  dev_deploy:
    jobs:
      - build:
          filters:
            branches:
              only:
                - /server-dev-.*/
      - push-dev-server:
          requires:
            - build
          filters:
            branches:
              only:
                - /server-dev-.*/
      - deploy-dev-server:
          requires:
            - push-server
          filters:
            branches:
              only:
                - /server-dev-.*/
```

Deploys with a stage of "prod" are created by pushing a tag that follows the
convention `server-prod-<descriptive name>`. As an extra precaution here, we've
added an approval step after the delivery step. Note that with Houston this
isn't strictly necessary, as it routes based both on stage and version. The new
deployment won't receive traffic until a release is executed, but the approval
helps keep the prod space uncluttered.

```
  prod_deploy:
    jobs:
      - build:
          filters:
            tags:
              only:
                - /server-prod-.*/
            branches:
              ignore: /.*/
      - push-prod-server:
          requires:
            - build
          filters:
            tags:
              only:
                - /server-prod-.*/
      - deploy-prod-server-hold:
          type: approval
          requires:
            - push-prod-server
          filters:
            tags:
              only:
                - /server-prod-.*/
      - deploy-prod-server:
          requires:
            - deploy-prod-server-hold
          filters:
            tags:
              only:
                - /server-prod-.*/
```

## Executing a Dev Deploy

Create a branch called server-dev-first-deploy, and push it to origin.

```console
git checkout -b server-dev-first-deploy
git push origin server-dev-first-deploy
```

CircleCI should see this branch push, match the branch pattern against the
dev_deploy workflow, and begin a build. You can go to

`https://circleci.com/gh/<your github org>/workflows/<your github repo>`

To follow the progress. When its finished, you should see a new deployment on
your Kubernetes cluster

```console
> kubectl get deployments
NAME                                                 DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
all-in-one-client                                    1         1         1            1           108d
all-in-one-server                                    1         1         1            1           108d
all-in-one-server-dev-server-dev-first-deploy        1         1         1            0           6m
rotor                                                1         1         1            1           108d
tbnproxy                                             1         1         1            1           108d
```

Inspecting this new deployment shows labels that indicate this is a _dev_
deployment, information to place it in the appropriate Turbine Labs cluster, and
information that lets us tie it back to the originating git sha.

```console
> kubectl describe deployment all-in-one-dev-server-dev-first-deploy
Name:			all-in-one-server-dev-server-dev-first-deploy
Namespace:		default
CreationTimestamp:	Mon, 21 Aug 2017 13:37:04 -0700
Labels:			app=all-in-one-server
			git_branch=server-dev-first-deploy
			git_sha=
			run=all-in-one-server
			stage=dev
			tbn_cluster=all-in-one-server
			version=server-dev-first-deploy

...
```
## Executing a Prod Deploy

Make any changes you want, merge it back to master and push it to
origin. CircleCI should see the code change, but because the branch pattern
doesn't match a dev deploy, and it's not a tag push, it will only execute the
build workflow. To execute a prod deploy, we'll need to create a tag and push it
to origin.

```console
git tag server-prod-v1.1
git push origin server-prod-v1.1
```

CircleCI sees this tag push, matches the tag against the prod_deploy workflow,
and initiates a build. When its finished, you should see a new deployment on
your Kubernetes cluster

```console
> kubectl get deployments
NAME                                         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
all-in-one-client                            1         1         1            1           105d
all-in-one-server                            1         1         1            1           105d
all-in-one-server-dev-2017-08-18-244f277b    1         1         1            1           10m
all-in-one-server-prod-2017-08-18-244f277b   1         1         1            1           2m
rotor                                        1         1         1            1           105d
tbnproxy                                     1         1         1            1           105d
```

Describing this deployment shows a similar tag set, but this one is labeled with
a stage of prod. This lets us use it in Houston release workflows.

```console
kubectl describe deployment all-in-one-server-prod-2017-08-18-244f277b
Name:			all-in-one-server-prod-2017-08-18-244f277b
Namespace:		default
CreationTimestamp:	Fri, 18 Aug 2017 08:49:51 -0700
Labels:			app=all-in-one-server
			git_branch=HEAD
			git_sha=244f277b8871a898e55a86e1c5fdbd48e9db9013
			run=all-in-one-server
			stage=prod
			tbn_cluster=all-in-one-server
			version=2017-08-18-244f277b
```

# Continuous Release

So we have a continuously tested application, and continuous deployment based on
branch and tag naming conventions. Note that none of these steps _automatically_
releases the code to customers, which gives us an opportunity to test and verify
changes on production infrastructure before we test with customers.

## Verify in Production

Navigate to your all-in-one application. If you completed the Kubernetes guide,
your all-in-one application should be showing all green boxes. You have created
two new deployments, but they haven't yet been released to prod customers.

To verify this before releasing to customers, add a query parameter to your
request that indicates the version of code you want your request routed to.
`http://<your service ip>/?X-Tbn-Version=<your deployment version>`,
e.g.
`http://104.196.242.214/?X-Tbn-Version=2017-08-18-244f277b`.

You should see pink flashing boxes. If you remove the query parameter you return
to green boxes.

Behind the scenes the all-in-one client is converting this query parameter to a
request header. Houston has configured tbnproxy to inspect this header, and
route traffic to a member of the all-in-one-server cluster whose version label
matches the value of the header. You can verify your new release on production
infrastructure before releasing it to customers.

## Better Verification in Production

With a browser plugin you can do even better. Houston Chrome Extension
(available in the
[Chrome Store](https://chrome.google.com/webstore/detail/houston-by-turbine-labs/bhigicedeaekhgjpgmpigofebngokpip?hl=en-US)
or as source [on github](https://github.com/turbinelabs/houston-crx)
talks to the Houston API, retrieving a list of deployed instances. It allows you
to set cookies on a page of the form  `Tbn-<service name>-Version=<desired
version`.  With the addition of a cookie-based routing rule, Houston can inspect
these cookies and route traffic to an appropriate service instance.

To execute this workflow, first add a request specific override
* In https://app.turbinelabs.io, navigate to your zone, then release groups, and
  click the pencil icon next to the server release group.
* At the bottom of the page, click Add an Override
* Add a match property that is a cookie named 'Tbn-All-in-one-server-Version',
  and in the value field select "Match All Values"
* The destination should be weight 1, to service "all-in-one-sserver".
* Click "Add constraint to all-in-one-server"
* The Constraint key should be "version", and the Constraint value should be
  "Tbn-All-in-one-server"

Now install the plugin, and use it to dynamically select a version of the server
to view.
* Navigate to your all in one demo page
* Right click anywhere on the page
* Look for the Houston Chrome extension context menu
* Select testbed (your zone), all-in-one-server (your cluster), and
  choose server-dev-first-deploy.

The boxes should change to #ffc0cb. Note that this isn't the version any
customers would see. This is you requesting to see a specific _deployed_, but
not _released_ version of the server code.

## Incremental Release

Convinced that pink is a superior color to what we've currently released, you
want to show this to all your customers. But what if not all customers enjoy the
soothing aura of #ffc0cb? This is where incremental release has huge
advantages. You can introduce risky code (and those of you jumping ahead may
correctly be pointing out that all code is risky) to a small fraction of the
customer base, observe its behavior, and turn off the route if things go poorly.

Navigate to the [Houston app](https://app.turbinelabs.io), select your
all-in-one zone, and navigate to release groups in the sparklines. The sparkline
for server should show a release ready. Expand the line, and click Start
Release. Drag the slider to 10%, and observe your all-in-one app. 10% of the
boxes should be pink. Assuming your customers are also fans of #ffc0cb, you can
gradually increase this percentage all the way up to 100%. If they revolt at the
change, you can cancel the release by dragging the slider to zero.
