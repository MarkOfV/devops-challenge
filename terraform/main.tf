provider "aws" {
  region = var.region
}


data "aws_ssm_parameter" "amazon_linux_2" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2" 
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.11.0.0/16" 
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.stack_name}::VPC" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.stack_name}::InternetGateway" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.11.0.0/20" 
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "${var.stack_name}::PublicSubnetA" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.stack_name}::PublicRouteTable" }
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web_sg" {
  name        = "web-server-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.stack_name}::PublicSecurityGroup"
  }
}

resource "aws_iam_role" "server_role" {
  name = "${var.stack_name}-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" 
}

resource "aws_iam_role_policy_attachment" "s3_readonly" {
  role       = aws_iam_role.server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess" 
}

resource "aws_iam_instance_profile" "deploy_profile" {
  name = "${var.stack_name}-InstanceProfile"
  role = aws_iam_role.server_role.name
}

resource "aws_instance" "web_server" {
  ami                  = data.aws_ssm_parameter.amazon_linux_2.value
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.deploy_profile.name
  subnet_id            = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y ruby wget
              cd /home/ec2-user
              wget https://aws-codedeploy-eu-west-1.s3.eu-west-1.amazonaws.com/latest/install
              chmod +x ./install
              sudo ./install auto
              EOF

  tags = {
    Name = "${var.stack_name}::WebServer"
    role = "webserver"
  }
}