terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id                              = aws_vpc.main.id
  cidr_block                          = "10.0.1.0/24"
  availability_zone                   = "us-east-1a"
  map_public_ip_on_launch             = true
  tags = {
    Name = "subnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id                              = aws_vpc.main.id
  cidr_block                          = "10.0.2.0/24"
  availability_zone                   = "us-east-1b"
  map_public_ip_on_launch             = true
  tags = {
    Name = "subnet2"
  }
}

#Private-Subnet
resource "aws_subnet" "privatesub" {
  vpc_id                              = aws_vpc.main.id
  cidr_block                          = "10.0.3.0/24"
  availability_zone                   = "us-east-1b"
  map_public_ip_on_launch             = true
  tags = {
    Name = "privatesub"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }

}

resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.main.id
route {
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.gw.id
}
  tags = {
    Name = "routetable"
  }

}

# #assiociation of route table to private SN 1 
# resource "aws_route_table_association" "greg_Private_RT_ass_01" {
#   subnet_id      = aws_subnet.greg_PRV_SN1.id
#   route_table_id = aws_route_table.greg_RT_Prv_SN.id
# }

# Create Frontend Security Group
resource "aws_security_group" "greg_FrontEnd_SG" {
  name        = "greg_FrontEnd_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from aws_vpc.main.id"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    description = "Allow jenkins from greg_VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "Allow http from greg_VPC"
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
    Name = "greg_FrontEnd_SG"
  }
}