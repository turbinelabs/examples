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

variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.

Example: ~/.ssh/terraform.pub
  DESCRIPTION
}

variable "key_name" {
  description = "Desired name of AWS key pair"
  default = "nlb-example"
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "us-west-1"
}

# Ubuntu Precise 12.04 LTS (x64)
variable "aws_amis" {
  default = {
    us-west-1 = "ami-23566a43"
  }
}

variable "instance_type" {
  description = "type of instance to use for proxies and servers"
  default = "t2.micro"
}

variable "AWS_ACCESS_KEY_ID" {
  description = "AWS access key to use"
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "AWS access key to use"
}

/*
# Uncomment the following variables, and replace the ExecStart entry in rotor.tf
# To connect Rotor to Houston

variable "ROTOR_API_KEY" {
  description = "Houston API key to use for Rotor"
}

variable "ROTOR_API_ZONE_NAME" {
  description = "Houston zone name to use for Rotor"
  default = "default-zone"
}
*/

variable "client_ami" {
  default = "ami-851820e5"
}

variable "server_ami" {
  default = "ami-be1e26de"
}

variable "rotor_ip" {
  default = "10.0.1.10"
}
