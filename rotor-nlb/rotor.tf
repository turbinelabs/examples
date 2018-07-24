/*
Copyright 2018 Turbine Labs, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

resource "aws_instance" "rotor" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "core"

    # The connection will use the local SSH agent for authentication.
  }

  tags {
    "rotor" = "",
    "version" = "0.18.2"
  }

  instance_type = "${var.instance_type}"

  # Lookup the correct AMI based on the region
  # we specified
  ami = "${lookup(var.aws_amis, var.aws_region)}"

  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.default.id}"]

  # We're going to launch into the same subnet as our NLB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_id = "${aws_subnet.default.id}"

  private_ip = "${var.rotor_ip}"
  user_data = <<USERDATA
#cloud-config

coreos:
  units:
    - name: "rotor.service"
      command: "start"
      content: |
        [Unit]
        Description=Rotor Service
        After=docker.service
        Requires=docker.service

        [Service]
        TimeoutStartSec=0
        Restart=always
        ExecStartPre=-/usr/bin/docker stop %n
        ExecStartPre=-/usr/bin/docker rm %n
        ExecStartPre=/usr/bin/docker pull turbinelabs/rotor:0.18.2
        ExecStart=/usr/bin/docker run --net host --name %n -e 'ROTOR_AWS_AWS_REGION=${var.aws_region}' -e 'ROTOR_AWS_AWS_ACCESS_KEY_ID=${var.AWS_ACCESS_KEY_ID}' -e 'ROTOR_AWS_AWS_SECRET_ACCESS_KEY=${var.AWS_SECRET_ACCESS_KEY}' -e 'ROTOR_AWS_VPC_ID=${aws_vpc.default.id}' -e 'ROTOR_CMD=aws' -p 50000:50000 turbinelabs/rotor:0.18.2

        [Install]
        WantedBy=multi-user.target
  USERDATA

  # You can replace the ExecStart line in the instance's user_data with the line below, and uncomment
  # the re;quired entries in variables.tf to connect your Rotor instance to Houston.
  # ExecStart=/usr/bin/docker run --net host --name %n -e 'ROTOR_API_ZONE_NAME=${var.ROTOR_API_ZONE_NAME}' -e 'ROTOR_API_KEY=${var.ROTOR_API_KEY}' -e 'ROTOR_AWS_AWS_REGION=${var.aws_region}' -e 'ROTOR_AWS_AWS_ACCESS_KEY_ID=${var.AWS_ACCESS_KEY_ID}' -e 'ROTOR_AWS_AWS_SECRET_ACCESS_KEY=${var.AWS_SECRET_ACCESS_KEY}' -e 'ROTOR_AWS_VPC_ID=${aws_vpc.default.id}' -e 'ROTOR_CMD=aws' -p 50000:50000 turbinelabs/rotor:0.18.2
}

