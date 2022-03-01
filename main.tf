terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-southeast-1"
}


# Create a VPC
resource "aws_vpc" "main" {
    cidr_block = "10.192.254.0/24"

  tags = {
       Name = "aws_internet_intranet"
   }
}

# Create Subnet Public AZ1
resource "aws_subnet" "public_az1" {
  availability_zone = "ap-southeast-1a"
  map_public_ip_on_launch = true
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.192.254.32/27"

  tags = {
    Name = "aws_internet_intranet_public_az1"
  }
}

# Create Subnet Public AZ2
resource "aws_subnet" "public_az2" {
  availability_zone = "ap-southeast-1b"
  map_public_ip_on_launch = true
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.192.254.64/27"

  tags = {
    Name = "aws_internet_intranet_public_az2"
  }
}

# Create Subnet for Webapp for az1
resource "aws_subnet" "private1_az1" {
  availability_zone = "ap-southeast-1a"
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.192.254.96/27"

  tags = {
    Name = "aws_internet_intranet_private1_az1"
  }
}

# Create Subnet for Webapp for az2
resource "aws_subnet" "private1_az2" {
  availability_zone = "ap-southeast-1b"
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.192.254.128/27"

  tags = {
    Name = "aws_internet_intranet_private2_az2"
  }
}


# Create Subnet for RDS for az1
resource "aws_subnet" "private2_az1" {
  availability_zone = "ap-southeast-1a"
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.192.254.160/27"

  tags = {
    Name = "aws_internet_intranet_private2_az1"
  }
}

# Create Subnet for RDS for az2
resource "aws_subnet" "private2_az2" {
  availability_zone = "ap-southeast-1b"
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.192.254.192/27"

  tags = {
    Name = "aws_internet_intranet_private2_az1"
  }
}


# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "aws_internet_intranet.igw"
  }
}

# Create Route Table
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_network_interface" "foo" {
  subnet_id   = aws_subnet.private1_az1.id

  tags = {
    Name = "primary_network_interface"
  }
}

# Create  WebApp EC2
resource "aws_instance" "app_server" {
  ami           = "ami-0da930e66ef2fc2e0"
  instance_type = "t2.micro"

  network_interface {
    network_interface_id = aws_network_interface.foo.id
    device_index         = 0
  }

  tags = {
    Name = "WebApp1"
  }
}

# Create  WebApp EC2 AMI
resource "aws_ami_from_instance" "webapp1" {
  name               = "webapp1_ami"
  source_instance_id = " i-072d9aa2d891e9931"
  tags = {
    Name = "WebApp1_AMI"
  }
}


# Create Target Group
resource "aws_lb_target_group" "WebApp-ASG-TG" {
  name     = "WebApp-ASG-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}


# Create ALB
resource "aws_lb" "WebApp-ALB" {
  name               = "WebApp-ALB"
  load_balancer_type = "application"

  subnet_mapping {
    subnet_id            = aws_subnet.public_az1.id
    
  }

  subnet_mapping {
    subnet_id            = aws_subnet.public_az2.id
    
  }
}

# Create ALB Listener
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = "arn:aws:elasticloadbalancing:ap-southeast-1:264162553877:loadbalancer/app/WebApp-ALB/e21f22cb1ed6b303"
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = "arn:aws:elasticloadbalancing:ap-southeast-1:264162553877:targetgroup/WebApp-ASG-lb-tg/5220b591d143e7cb"
 }
}

# Create AWS Launch Configuration
resource "aws_launch_configuration" "as_conf" {
  image_id      = "ami-07a20ca7b3e03bb19"
  instance_type = "t2.micro"
}


# Create ASG
resource "aws_autoscaling_group" "WebApp_ASG2" {
  desired_capacity   = 2
  max_size           = 2
  min_size           = 2
  health_check_type  = "ELB"
  launch_configuration = aws_launch_configuration.as_conf.name
  vpc_zone_identifier  = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
  target_group_arns = ["arn:aws:elasticloadbalancing:ap-southeast-1:264162553877:targetgroup/WebApp-ASG-lb-tg/5220b591d143e7cb"]
    tag {
    key                 = "Name"
    value               = "WebApp-ASG2"
    propagate_at_launch = true
  }

    instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }
}

# Create RDS instance with multi AZ
resource "aws_db_instance" "default" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  name                 = "webappdb"
  username             = "user"
  password             = "password"
  parameter_group_name = "default.mysql5.7"
  multi_az = true
  skip_final_snapshot  = true
}


resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.private2_az1.id, aws_subnet.private2_az2.id]

  tags = {
    Name = "My DB subnet group"
  }
}