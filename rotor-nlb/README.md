
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

# CloudFormation + NLB + Envoy with Rotor

This repository walks through installing and configuring Envoy behind an
[AWS Network Load Balancer](http://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html).
At the end of the exercise you'll have:
* an NLB sending all traffic to a pool of Envoy proxies in an autoscaling group
* Envoy routing traffic to two different backing services, also in autoscaling
  groups
* rotor providing an xDS implementations that keeps Envoy in sync with
  autoscaling group changes

Creating the CloudFormation stacks will deploy two demonstration services. The
client application presents a simple UI that shows blinking boxes. It calls the
server application, which returns a hex color that the boxes should be colored.
CloudFormation will also deploy [envoy-simple](https://github.com/turbinelabs
/envoy-simple), configured as a target group for a network load balancer.

It will also deploy rotor to track the configuration of your
environment. And provide a
[Cluster Discovery Service](https://www.envoyproxy.io/docs/envoy/v1.5.0/api-v2/cds.proto)
and
[Endpoint Discovery Service](https://www.envoyproxy.io/docs/envoy/v1.5.0/api-v2/eds.proto)
implementation that integrates with the AWS Autoscaling Groups, as well as a very
simple
[Listener Discovery Service](https://www.envoyproxy.io/docs/envoy/v1.5.0/api-v2/lds.proto)
implementation.

With these in place, Envoy will automatically discover and route to EC2
instances that are created by Autoscaling Groups. With basic functionality in
place, we'll configure Envoy to support multiple backends in a single virtual
host the hard way, and then show how simple it is to add this environment to
Houston, for a much simpler, observable implementation of listener and route
management.

# Prerequisites #

Before getting started you'll need the following:

## An AWS Account ##

You can [sign up for an account](https://aws.amazon.com/) if you don't have
one. You'll need permissions to create VPCs, NLBs, EC2 instances, and
autoscaling groups. You'll also need
[an access key](http://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html).

## A VPC ##

To launch the stack you'll need a VPC configured with at least two subnets in
different availability zones

# Getting Started

## Setting up the Envoy stack

Go to the [AWS console](https://console.aws.amazon.com), select the region in
which you wish to launch your stack, and click "CloudFormation" under the
Management Tools section.

Click "Create Stack" in the top left section of the screen. In the "Select
Template" screen choose "Upload a template to Amazon S3", click "choose file",
and select the cloud-formation-envoy.yaml file in this repository. Then click
"Next".

In the "Specify Details" screen fill in appropriate variables. You can name your
stack anything you like. You will need to select two subnets, each running in
different Availability Zones, to provide redundancy for your proxy pool.

Click through the rest of the screens, and launch your stack. Note that
provisioning a load balancer in AWS can take several minutes.

When the stack is created, move on to creating the application.

## Deploying the application

Go to the [AWS console](https://console.aws.amazon.com) again, select the region
in  which you wish to launch your stack, and click "CloudFormation" under the
"Management Tools" section.

Click "Create Stack" in the top left section of the screen. In the "Select
Template" screen choose "Upload a template to Amazon S3", click "choose file",
and select the cloud-formation-client.yaml file in this repository. Then click
"Next".

In the "Specify Details" screen fill in appropriate variables. You can name your
stack anything you like, but the security group you choose must include the
"InstanceSecurityGroup" created as part of the Envoy stack.

Create another stack for the server application by repeating these steps using
the cloud-formation-server.yaml file.

## Success

Now you should be able to visit your domain. If you look at the Envoy stack in
the CloudFormation UI, the "Outputs" tab will have an entry for "URL" e.g.

`http://cfenv-loadb-13m1i0qii67te-37085f4fe3c82383.elb.us-west-1.amazonaws.com`

If you visit this URL directly you'll receive a 404. This is because Envoy has
set up a virtual host for each service ("client" and "server"). To make valid
requests you'll need to override the Host header, e.g.

`curl -H 'Host: client' <your load balancer URL>`

## Cleanup

You can remove all created resources by running choosing to delete the stack in
the CloudFormation UI.
