# devsecops-project
devsecops-project

# Terraform configuration for AWS
provider "aws" {
  region = "us-east-1" # Change as needed
}

# Define variables
variable "instance_type" {
  default = "t2.micro"
}

variable "ami" {
  default = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI (update as needed)
}

# Security group for EC2 and Load Balancer
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
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
  count         = 2
  ami           = var.ami
  instance_type = var.instance_type
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

# Create Elastic Load Balancer
resource "aws_elb" "web_elb" {
  name               = "web-elb"
  availability_zones = data.aws_availability_zones.available.names
  security_groups    = [aws_security_group.web_sg.id]

  listener {
	instance_port     = 80
	instance_protocol = "HTTP"
	lb_port           = 80
	lb_protocol       = "HTTP"
  }

  health_check {
	target              = "HTTP:80/"
	interval            = 30
	timeout             = 5
	healthy_threshold   = 2
	unhealthy_threshold = 2
  }

  instances = aws_instance.web_server.*.id

  tags = {
	Name = "web-elb"
  }
}

# Output the Load Balancer DNS
output "elb_dns_name" {
  value = aws_elb.web_elb.dns_name
}
