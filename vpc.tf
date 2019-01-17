/*=== VARIABLES AND DATA ===*/

variable "vpc" {
  type    = "map"
  default = {
    "tag"         = ""
    "cidr_block"  = ""
    "subnet_size" = ""
  }
}

variable "launch_config" {
  type    = "map"
  default = {
    "instance_type" = ""
    "startup_file_path" = ""
  }
}

variable "autoscaling_config" {
  type    = "map"
  default = {
    "min_size" = ""
    "desired_capacity" = ""
    "max_size" = ""
  }
}

locals {
  subnet_newbits = "${32 - log(var.vpc["subnet_size"], 2) - element(split("/", aws_vpc.main.cidr_block), 1)}"
}

data "aws_ami" "go_app" {
  most_recent = true

  filter {
    name   = "name"
    values = ["packer-example*"]
  }
}

data "template_file" "launch_config" {
  template = "${file("${var.launch_config["startup_file_path"]}")}"
  vars {
    deployment_group = "ami-${random_id.deployment_group.hex}"
  }
}


/*=== VPC RESOURCES ===*/

resource "aws_vpc" "main" {
  cidr_block = "${var.vpc["cidr_block"]}"
  tags {
    Name     = "VPC-${var.vpc["tag"]}"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_subnet" "public" {
  count = "${length(data.aws_availability_zones.allzones.names)}"

  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${cidrsubnet(aws_vpc.main.cidr_block, local.subnet_newbits, count.index)}"
  map_public_ip_on_launch = true
  availability_zone       = "${element(data.aws_availability_zones.allzones.names, count.index)}"

  tags = {
    Name = "${lower(var.vpc["tag"])}-public-subnet-${element(data.aws_availability_zones.allzones.names, count.index)}"
  }
}

resource "aws_subnet" "private" {
  count = "${length(data.aws_availability_zones.allzones.names)}"

  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${cidrsubnet(aws_vpc.main.cidr_block, local.subnet_newbits, count.index + length(data.aws_availability_zones.allzones.names))}"
  availability_zone       = "${element(data.aws_availability_zones.allzones.names, count.index)}"

  tags = {
    Name = "${lower(var.vpc["tag"])}-private-subnet-${element(data.aws_availability_zones.allzones.names, count.index)}"
  }
}

resource "aws_eip" "nat_gateway_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = "${aws_eip.nat_gateway_eip.id}"
  subnet_id     = "${element(aws_subnet.public.*.id, 0)}"
}

resource "random_id" "deployment_group" {
  keepers = {
    ami_id = "${data.aws_ami.go_app.id}"
  }
  byte_length = 8
}

resource "aws_launch_configuration" "go_app" {
  image_id        = "${data.aws_ami.go_app.id}"
  instance_type   = "${var.launch_config["instance_type"]}"
  security_groups = ["${aws_security_group.go_app.id}"]
  key_name        = "${var.key_name}"
  user_data       = "${data.template_file.launch_config.rendered}"
  lifecycle {
    create_before_destroy = true
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

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "terraform-elb-go-app"
  }
}

resource "aws_autoscaling_group" "go_app" {
  name                 = "${aws_launch_configuration.go_app.name}-asg"
  launch_configuration = "${aws_launch_configuration.go_app.name}"
  vpc_zone_identifier  = ["${aws_subnet.public.*.id}"]
  
  min_size             = "${var.autoscaling_config["min_size"]}"
  desired_capacity     = "${var.autoscaling_config["desired_capacity"]}"
  max_size             = "${var.autoscaling_config["max_size"]}"
  
  load_balancers = ["${aws_elb.go_app.id}"]
  health_check_type = "ELB"

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key = "Name"
    value = "terraform-asg"
    propagate_at_launch = true
  }
  tag {
    key                 = "deployment_group"
    value               = "ami-${random_id.deployment_group.hex}"
    propagate_at_launch = true
  }
  # tag {
  #   key                 = "app_name"
  #   value               = "${data.aws_ami.go_app.id}"
  #   propagate_at_launch = true
  # }
}