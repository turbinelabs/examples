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

resource "aws_autoscaling_group" "all-in-one-client" {
  name = "client"
  tag {
    key = "tbn:cluster:client:8080"
    value = "client"
    propagate_at_launch = true
  }
  tag {
    key = "tbn:cluster:client:8080:version"
    value = "0.16.0-rc1"
    propagate_at_launch = true
  }
  tag {
    key = "tbn:cluster:client:8080:stage"
    value = "prod"
    propagate_at_launch = true
  }

  min_size = 1
  max_size = 3
  vpc_zone_identifier = ["${aws_subnet.default.id}"]
  launch_configuration = "${aws_launch_configuration.all-in-one-client.id}"
}

resource "aws_launch_configuration" "all-in-one-client" {

  name = "client-lc"
  image_id = "${lookup(var.aws_amis, var.aws_region)}"
  instance_type = "${var.instance_type}"

  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  # Our Security group to allow HTTP and SSH access
  security_groups = ["${aws_security_group.default.id}"]

  user_data = <<USERDATA
#cloud-config

coreos:
  units:
    - name: "all-in-one-client.service"
      command: "start"
      content: |
        [Unit]
        Description=All-in-one client Service
        After=docker.service
        Requires=docker.service

        [Service]
        TimeoutStartSec=0
        Restart=always
        ExecStartPre=-/usr/bin/docker stop %n
        ExecStartPre=-/usr/bin/docker rm %n
        ExecStartPre=/usr/bin/docker pull turbinelabs/all-in-one-client:0.16.0-rc1
        ExecStart=/usr/bin/docker run --name %n -p 8080:8080 turbinelabs/all-in-one-client:0.16.0-rc1

        [Install]
        WantedBy=multi-user.target
  USERDATA
}

resource "aws_autoscaling_group" "all-in-one-server" {
  name = "server"
  tag {
    key = "tbn:cluster:server:8080"
    value = "server"
    propagate_at_launch = true
  }
  tag {
    key = "tbn:cluster:server:8080:version"
    value = "0.16.0-rc1"
    propagate_at_launch = true
  }
  tag {
    key = "tbn:cluster:server:8080:stage"
    value = "prod"
    propagate_at_launch = true
  }

  min_size = 1
  max_size = 3
  vpc_zone_identifier = ["${aws_subnet.default.id}"]
  launch_configuration = "${aws_launch_configuration.all-in-one-server.id}"
}

resource "aws_launch_configuration" "all-in-one-server" {
  name = "server-lc"
  image_id = "${lookup(var.aws_amis, var.aws_region)}"
  instance_type = "${var.instance_type}"

  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  # Our Security group to allow HTTP and SSH access
  security_groups = ["${aws_security_group.default.id}"]
  user_data = <<USERDATA
#cloud-config

coreos:
  units:
    - name: "all-in-one-server.service"
      command: "start"
      content: |
        [Unit]
        Description=All-in-one server Service
        After=docker.service
        Requires=docker.service

        [Service]
        TimeoutStartSec=0
        Restart=always
        ExecStartPre=-/usr/bin/docker stop %n
        ExecStartPre=-/usr/bin/docker rm %n
        ExecStartPre=/usr/bin/docker pull turbinelabs/all-in-one-server:0.16.0-rc1
        ExecStart=/usr/bin/docker run --name %n -e 'TBN_COLOR=1B9AE4' -p 8080:8080 turbinelabs/all-in-one-server:0.16.0-rc1

        [Install]
        WantedBy=multi-user.target
  USERDATA
}

resource "aws_autoscaling_policy" "all-in-one-server-out" {
  name = "all-in-one-server-scale-out"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.all-in-one-server.name}"
}

resource "aws_cloudwatch_metric_alarm" "all-in-one-server-bytes-alarm-out" {
  alarm_name = "all-in-one-server-bytes-alarm-out"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "NetworkIn"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "1000000"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.all-in-one-server.name}"
  }

  alarm_description = "This metric monitors All-in-one-server network utilization"
  alarm_actions = ["${aws_autoscaling_policy.all-in-one-server-out.arn}"]
}

resource "aws_autoscaling_policy" "all-in-one-server-in" {
  name = "all-in-one-server-scale-in"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.all-in-one-server.name}"
}

resource "aws_cloudwatch_metric_alarm" "all-in-one-server-bytes-alarm-in" {
  alarm_name = "all-in-one-server-bytes-alarm-in"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "NetworkIn"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "800000"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.all-in-one-server.name}"
  }

  alarm_description = "This metric monitors All-in-one-server network utilization"
  alarm_actions = ["${aws_autoscaling_policy.all-in-one-server-in.arn}"]
}

resource "aws_autoscaling_policy" "all-in-one-client-out" {
  name = "all-in-one-client-scale-out"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.all-in-one-client.name}"
}

resource "aws_cloudwatch_metric_alarm" "all-in-one-client-bytes-alarm-out" {
  alarm_name = "all-in-one-client-bytes-alarm-out"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "NetworkIn"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "1000000"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.all-in-one-client.name}"
  }

  alarm_description = "This metric monitors All-in-one-client network utilization"
  alarm_actions = ["${aws_autoscaling_policy.all-in-one-client-out.arn}"]
}

resource "aws_autoscaling_policy" "all-in-one-client-in" {
  name = "all-in-one-client-scale-in"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.all-in-one-client.name}"
}

resource "aws_cloudwatch_metric_alarm" "all-in-one-client-bytes-alarm-in" {
  alarm_name = "all-in-one-client-bytes-alarm-in"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "NetworkIn"
  namespace = "AWS/EC2"
  period = "60"
  statistic = "Average"
  threshold = "800000"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.all-in-one-client.name}"
  }

  alarm_description = "This metric monitors All-in-one-client network utilization"
  alarm_actions = ["${aws_autoscaling_policy.all-in-one-client-in.arn}"]
}
