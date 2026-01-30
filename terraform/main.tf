terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

#vpc 

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "main_vpc"
  }
}

# Internet Gateway (required for public subnets and outbound traffic)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-igw"
  }
}

# Public route table - routes all outbound traffic via IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "public-rt"
  }
}

# Subnets (public - with IGW route and auto-assign public IP)
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidrs[0]
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidrs[1]
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-2"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

# Security group for ALB - allow HTTP from internet
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

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
  tags = {
    Name = "alb-sg"
  }
}

# Security group for app instances - allow traffic only from ALB on app port (3000)
resource "aws_security_group" "app" {
  name        = "app-sg"
  description = "Security group for Node.js app instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow traffic from ALB to app port"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "app-sg"
  }
}

