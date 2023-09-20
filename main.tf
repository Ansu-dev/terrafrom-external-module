terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.17.0" # 최신 버전
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}


module "default_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "default_vpc_${terraform.workspace}"
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-2a", "ap-northeast-2b"]
  public_subnets  = ["10.0.100.0/24", "10.0.101.0/24"]


  default_security_group_name = "default_security_group"

  tags = {
    Terraform   = "true"
    Environment = terraform.workspace
  }
}

resource "aws_instance" "web_instances" {
  count = 2
  ami = "ami-091aca13f89c7964e"
  instance_type = "t3.micro"

  subnet_id = module.default_vpc.public_subnets[count.index] # 1개의 vpc에 2개의 인스턴스를 만들어야하기때문

  tags = {
    Name = "web_${count.index}"
  }
}

module "web_elb" {
  source  = "terraform-aws-modules/elb/aws"
  version = "~> 2.0"

  name = "web-elb"

  subnets         = module.default_vpc.public_subnets
  security_groups = [module.default_vpc.default_security_group_id]
  internal        = false

  listener = [
    {
      instance_port     = 80
      instance_protocol = "HTTP"
      lb_port           = 80
      lb_protocol       = "HTTP"
    },
  ]

  health_check = {
    target              = "HTTP:80/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  number_of_instances = 2
  instances           = aws_instance.web_instances[*].id
}