terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "<5.0"
    }

    random = { source = "hashicorp/random" }
  }
}

provider "aws" {
  region = "us-west-2"
}

data "aws_vpc" "this" {
  default = true
}

data "aws_security_group" "this" {
  name   = "default"
  vpc_id = data.aws_vpc.this.id
}

data "aws_subnets" "this" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
}

data "aws_ami" "this" {
  most_recent = true
  name_regex  = "^spacelift-\\d{10}-arm64$"
  owners      = ["643313122712"]

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

#### Spacelift worker pool ####

module "this" {
  source = "../../"

  configuration              = <<-EOT
    export SPACELIFT_TOKEN="${var.spacelift_token}"
    export SPACELIFT_POOL_PRIVATE_KEY="${var.spacelift_pool_private_key}"
  EOT
  ami_id                     = data.aws_ami.this.id
  ec2_instance_type          = "m7g.medium"
  security_groups            = [data.aws_security_group.this.id]
  spacelift_api_key_endpoint = var.spacelift_api_key_endpoint
  spacelift_api_key_id       = var.spacelift_api_key_id
  spacelift_api_key_secret   = var.spacelift_api_key_secret
  vpc_subnets                = data.aws_subnets.this.ids
  worker_pool_id             = var.worker_pool_id
  min_size = 1
  max_size = 1

  tag_specifications = [
    {
      resource_type = "instance"
      tags = {
        Name = "sp5ft-${var.worker_pool_id}"
      }
    },
    {
      resource_type = "volume"
      tags = {
        Name = "sp5ft-${var.worker_pool_id}"
      }
    },
    {
      resource_type = "network-interface"
      tags = {
        Name = "sp5ft-${var.worker_pool_id}"
      }
    }
  ]
}
