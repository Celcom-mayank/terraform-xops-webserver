terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

################################################################################
# Networking
################################################################################
resource "aws_vpc" "web_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "xops-web-vpc" }
}

data "aws_availability_zones" "azs" {}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.azs.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "xops-public-subnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.web_vpc.id
  tags   = { Name = "xops-igw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.web_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "xops-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

################################################################################
# Security
################################################################################
resource "aws_security_group" "web_sg" {
  name_prefix = "xops-web-sg-"
  description = "Allow HTTP (80) and SSH (22)"
  vpc_id      = aws_vpc.web_vpc.id

  ingress {
    description = "SSH from anywhere (tighten in prod)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
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

  tags = { Name = "xops-web-sg" }
}

################################################################################
# EC2 Web Server
################################################################################
data "aws_ami" "amazon_linux_2023" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_pair_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl enable httpd
              systemctl start httpd
              cat > /var/www/html/index.html <<'EOT'
              <html>
                <head><title>XOps Web Server</title></head>
                <body style="font-family:sans-serif;text-align:center;margin-top:20%;">
                  <h1>🚀 Deployed via Terraform!</h1>
                  <p>If you can read this, your infra works 🎉</p>
                </body>
              </html>
              EOT
              EOF

  tags = { Name = "xops-web-instance" }
}
