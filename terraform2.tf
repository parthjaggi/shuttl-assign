variable "provider" {
  type = "map"
  default = {
    access_key = ""
    secret_key = ""
    region     = ""
  }
}
# variable "vpc" {
#   type    = "map"
#   default = {
#     "tag"         = ""
#     "cidr_block"  = ""
#     "subnet_bits" = ""
#   }
# }

# variable "access_key" {
#   default = "${var.provider.access_key}"
# }
# variable "secret_key" {
#   default = "${var.provider.secret_key}"
# }

# variable "region" {
#   default = "us-west-2"
# }

provider "aws" {
  access_key = "${var.provider["access_key"]}"
  secret_key = "${var.provider["secret_key"]}"
  region     = "${var.region}"
}




# below from https://medium.com/@ratulbasak93/aws-elb-and-autoscaling-using-terraform-9999e6266734

variable "public_key_path" {
  default = "/home/parth/repos/keys/practice.pem"
}
variable "key_name" {
  default = "practice"
}




# below from: https://ops.tips/blog/a-pratical-look-at-basic-aws-networking/

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.main.id}"
}

data "aws_availability_zones" "allzones" {}

variable "name" {
  default = "shuttl"
}

variable "subnet_size" {
  default = 4096
}

locals {
  subnet_newbits = "${32 - log(var.subnet_size, 2) - element(split("/", aws_vpc.main.cidr_block), 1)}"
}

resource "aws_subnet" "public" {
  count = "${length(data.aws_availability_zones.allzones.names)}"

  cidr_block              = "${cidrsubnet(aws_vpc.main.cidr_block, local.subnet_newbits, count.index)}"
  vpc_id                  = "${aws_vpc.main.id}"
  map_public_ip_on_launch = true
  availability_zone       = "${element(data.aws_availability_zones.allzones.names, count.index)}"

  tags = {
    Name = "${var.name}-public-subnet-${element(data.aws_availability_zones.allzones.names, count.index)}"
  }
}

resource "aws_subnet" "private" {
  count = "${length(data.aws_availability_zones.allzones.names)}"

  cidr_block              = "${cidrsubnet(aws_vpc.main.cidr_block, local.subnet_newbits, count.index + length(data.aws_availability_zones.allzones.names))}"
  vpc_id                  = "${aws_vpc.main.id}"
  availability_zone       = "${element(data.aws_availability_zones.allzones.names, count.index)}"

  tags = {
    Name = "${var.name}-private-subnet-${element(data.aws_availability_zones.allzones.names, count.index)}"
  }
}

resource "aws_eip" "nat_gateway_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = "${aws_eip.nat_gateway_eip.id}"
  subnet_id     = "${element(aws_subnet.public.*.id, 0)}"
}

resource "aws_route_table" "rt_internet_gateway" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }
}

resource "aws_route_table" "rt_nat_gateway" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.nat_gateway.id}"
  }
}

resource "aws_route_table_association" "rta_public_subnet" {
  count          = "${length(data.aws_availability_zones.allzones.names)}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.rt_internet_gateway.id}"
}

resource "aws_route_table_association" "rta_private_subnet" {
  count          = "${length(data.aws_availability_zones.allzones.names)}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${aws_route_table.rt_nat_gateway.id}"
}





# launch configuration
# from: https://medium.com/@I_M_Harsh/build-and-deploy-using-jenkins-packer-and-terraform-40b2aafedaec
# security from: https://ops.tips/blog/a-pratical-look-at-basic-aws-networking/

data "aws_ami" "go_app" {
  most_recent = true

  filter {
    name   = "name"
    values = ["packer-example*"]
  }
}

resource "aws_launch_configuration" "go_app" {
  image_id        = "${data.aws_ami.go_app.id}"
  instance_type   = "t2.micro"
  security_groups = ["${aws_security_group.go_app.id}"]
  key_name        = "${var.key_name}"
  user_data       = <<-EOF
                    #!/bin/bash
                    sudo http-echo -listen=:80 -text="hello world" &
                    EOF
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "go_app" {
  name = "security_group_for_go_server"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80 
    to_port     = 80 
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "go_app" {
  name                 = "${aws_launch_configuration.go_app.name}-asg"
  launch_configuration = "${aws_launch_configuration.go_app.name}"
  vpc_zone_identifier  = ["${aws_subnet.public.*.id}"]
  
  min_size             = 1
  desired_capacity     = 2
  max_size             = 4
  
  load_balancers = ["${aws_elb.go_app.id}"]
  # health_check_type = "ELB"

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key = "Name"
    value = "terraform-asg"
    propagate_at_launch = true
  }
}





resource "aws_elb" "go_app" {
  name               = "terraform-asg-go-app"
  security_groups    = ["${aws_security_group.elastic_lb.id}"]
  subnets            = ["${aws_subnet.public.*.id}"]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }
  # listener {
  #   lb_port            = 80
  #   lb_protocol        = "http"
  #   instance_port      = 443
  #   instance_protocol  = "https"
  #   ssl_certificate_id = "${var.app["ssl_cert_arn"]}"
  # }
  # listener {
  #   lb_port            = 443
  #   lb_protocol        = "https"
  #   instance_port      = 443
  #   instance_protocol  = "https"
  #   ssl_certificate_id = "${var.app["ssl_cert_arn"]}"
  # }

  # health_check {
  #   healthy_threshold   = 2
  #   unhealthy_threshold = 2
  #   timeout             = 3
  #   target              = "HTTP:80/"
  #   interval            = 30
  # }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "terraform-elb-go-app"
  }
}

resource "aws_security_group" "elastic_lb" {
  name = "security_group_for_elastic_lb"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}


























# if could not connect to instance in auto-scaling group:
# make instance in public and private subnet as done below.

# below from: goat icon, https://ops.tips/blog/a-pratical-look-at-basic-aws-networking/#creating-aws-vpc-subnets

# resource "aws_instance" "inst1" {
#   instance_type = "t2.micro"
#   ami           = "${data.aws_ami.ubuntu.id}"
#   key_name      = "${aws_key_pair.main.id}"
#   subnet_id     = "${module.networking.az-subnet-id-mapping["subnet1"]}"
# }

# resource "aws_instance" "inst2" {
#   instance_type = "t2.micro"
#   ami           = "${data.aws_ami.ubuntu.id}"
#   key_name      = "${aws_key_pair.main.id}"
#   subnet_id     = "${module.networking.az-subnet-id-mapping["subnet2"]}"
# }
