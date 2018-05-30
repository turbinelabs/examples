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

resource "aws_lb" "envoy" {
  name = "terraform-example-nlb"

  subnets         = ["${aws_subnet.default.id}"]
  load_balancer_type = "network"
}

resource "aws_lb_target_group" "envoy" {
  name     = "envoy-target-group"
  port     = 80
  protocol = "TCP"
  vpc_id   = "${aws_vpc.default.id}"
  target_type = "instance"
}

resource "aws_lb_listener" "envoy" {
  load_balancer_arn = "${aws_lb.envoy.id}"
  port     = 80
  protocol = "TCP"

  "default_action" {
    "target_group_arn" = "${aws_lb_target_group.envoy.id}"
    "type" = "forward"
  }
}

resource "aws_autoscaling_group" "envoy" {
  name = "envoy"
  min_size = 1
  max_size = 3
  vpc_zone_identifier = ["${aws_subnet.default.id}"]
  launch_configuration = "${aws_launch_configuration.envoy.id}"
  target_group_arns = ["${aws_lb_target_group.envoy.arn}"]
}

resource "aws_launch_configuration" "envoy" {
  name = "envoy-lc"
  image_id = "${lookup(var.aws_amis, var.aws_region)}"
  instance_type = "${var.instance_type}"

  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  # Our Security group to allow HTTP and SSH access
  security_groups = ["${aws_security_group.nlb.id}", "${aws_security_group.default.id}"]

  user_data = <<USERDATA
#cloud-config

coreos:
  units:
    - name: "envoy.service"
      command: "start"
      content: |
        [Unit]
        Description=Envoy Service
        After=docker.service
        Requires=docker.service

        [Service]
        TimeoutStartSec=0
        Restart=always
        ExecStartPre=-/usr/bin/docker stop %n
        ExecStartPre=-/usr/bin/docker rm %n
        ExecStartPre=/usr/bin/docker pull turbinelabs/envoy-simple:latest
        ExecStart=/usr/bin/docker run --name %n -e 'ENVOY_XDS_HOST=${var.rotor_ip}' -p 80:80 -p 9999:9999 turbinelabs/envoy-simple:0.17.0

        [Install]
        WantedBy=multi-user.target
  USERDATA
}

resource "aws_autoscaling_policy" "envoyout" {
  name = "envoy-scale-out"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.envoy.name}"
}

resource "aws_cloudwatch_metric_alarm" "bytesalarm-out" {
  alarm_name = "envoy-bytes-alarm-out"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "NetworkIn"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "1000000"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.envoy.name}"
  }

  alarm_description = "This metric monitors Envoy network utilization"
  alarm_actions = ["${aws_autoscaling_policy.envoyout.arn}"]
}

#
resource "aws_autoscaling_policy" "envoyin" {
  name = "envoy-scale-in"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.envoy.name}"
}

resource "aws_cloudwatch_metric_alarm" "bytesalarm-in" {
  alarm_name = "envoy-bytes-alarm-in"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "NetworkIn"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "800000"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.envoy.name}"
  }

  alarm_description = "This metric monitors Envoy network utilization"
  alarm_actions = ["${aws_autoscaling_policy.envoyin.arn}"]
}
