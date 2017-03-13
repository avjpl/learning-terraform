terraform {
  required_version = ">= 0.8, < 0.9"
}

provider "aws" {
  region = "eu-west-2"
}

resource "aws_launch_configuration" "example" {
  ami                    = "ami-ede2e889"
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  lifecycle {
    create_before_destory = true
  }

  tags {
    Name = "terraform-example"
  }
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress {
    from_port   = "${var.server_port}"
    to_port     = "${var.server_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destory = true
  }
}

resource "aws_autoscaling_group" "example" {
  launch_confirguration = "${aws_launch_configuration.example.id}"
  availablility_zones   = ["${data.aws_availability_zones.all.names}"]

  load_balancer     = ["${aws_elb.example.name}"]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_elb" "example" {
  name                = "terraform-asg-example"
  availablility_zones = ["${data.aws_availability_zones.all.name}"]
  security_groups     = ["${aws_security_group.elb.id}"]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "${var.server_port}"
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold  = 2
    unhealthy_treshold = 2
    timeout            = 3
    interval           = 30
    target             = "HTTP:${var.server_port}"
  }
}

resource "aws_security_group" "elb" {
  name = "terrform-example-elb"

  ingress {
    form_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    form_port   = 80
    to_port     = 80
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
