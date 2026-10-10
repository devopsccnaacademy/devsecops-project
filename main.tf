provider "aws" {
  region = "ap-south-1"
}

# Random ID for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Security group for EC2 and ALB
resource "aws_security_group" "web_sg" {
  name        = "web-sg-${random_id.suffix.hex}"
  description = "Allow HTTP and SSH traffic"

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
}

# Launch EC2 instances
resource "aws_instance" "web_server" {
  count           = 2
  ami             = "ami-08e3b3155fc937a94"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              echo "Hello from server $(hostname)" > /var/www/html/index.html
              systemctl start httpd
              systemctl enable httpd
            EOF

  tags = {
    Name = "web-server-${count.index + 1}"
  }
}

# Create Target Group
resource "aws_lb_target_group" "web_tg" {
  name        = "web-target-group-${random_id.suffix.hex}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Attach EC2 instances to Target Group
resource "aws_lb_target_group_attachment" "web_tg_attachment" {
  count            = 2
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_server[count.index].id
  port             = 80
}

# Create ALB
resource "aws_lb" "web_alb" {
  name               = "web-alb-${random_id.suffix.hex}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = false
  idle_timeout               = 60

  tags = {
    Name = "web-alb"
  }
}

# Create Listener for ALB
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Data sources for VPC and Subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Output the ALB DNS Name
output "alb_dns_name" {
  value = aws_lb.web_alb.dns_name
}
