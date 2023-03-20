variable "access_key" {
  type = string
}
variable "secret_key" {
  type = string
}


provider "aws" {
  region     = "us-west-2"
  access_key = var.access_key
  secret_key = var.secret_key
}

# vpc creation
resource "aws_vpc" "sbi-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "sbi-vpc"
  }
}

#public subnet creation
resource "aws_subnet" "sbi-public-subnet" {
  vpc_id     = aws_vpc.sbi-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Public-subnet"
  }
}

#private subnet creation
resource "aws_subnet" "sbi-private-subnet" {
  vpc_id     = aws_vpc.sbi-vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "private-subnet"
  }
}

#security group creation
resource "aws_security_group" "sbi-sg" {
  name        = "sbi-sg"
  description = "sbi-sg"
  vpc_id      = aws_vpc.sbi-vpc.id

  ingress {
    description = "Setting inbound for ssh"
    from_port   = 22
    to_port     = 22
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
    Name = "sbi-security-group"
  }
}

#creation of IGW
resource "aws_internet_gateway" "sbi-igw" {
  vpc_id = aws_vpc.sbi-vpc.id

  tags = {
    Name = "sbi-igw"
  }
}

#creation of elastic ip for public instance
resource "aws_eip" "lb1" {
  instance = aws_instance.web-instance.id
  vpc      = true
}

#creation of elastic ip for nat gateway
resource "aws_eip" "lb2" {
  vpc = true
}

#creation of NGW
resource "aws_nat_gateway" "sbi-ngw" {
  allocation_id = aws_eip.lb2.id
  subnet_id     = aws_subnet.sbi-public-subnet.id

  tags = {
    Name = "sbi-ngw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.sbi-igw]
}

#creation of Public-rt
resource "aws_route_table" "sbi-public-rt" {
  vpc_id = aws_vpc.sbi-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sbi-igw.id
  }

  tags = {
    Name = "sbi-public-rt"
  }
}

#creation of public-subnet-association
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.sbi-public-subnet.id
  route_table_id = aws_route_table.sbi-public-rt.id
}

#creation of Private-rt
resource "aws_route_table" "sbi-private-rt" {
  vpc_id = aws_vpc.sbi-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.sbi-ngw.id
  }

  tags = {
    Name = "sbi-private-rt"
  }
}
#creation of public-subnet-association
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.sbi-private-subnet.id
  route_table_id = aws_route_table.sbi-private-rt.id
}

#creation of keypair
resource "aws_key_pair" "sbi-deployer" {
  key_name   = "sbi-key"
  public_key = file("${path.module}/sbi-key.pub")
}

#creation of public-instance
resource "aws_instance" "web-instance" {
  ami                    = "ami-0d2017e886fc2c0ab"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.sbi-deployer.key_name
  vpc_security_group_ids = [aws_security_group.sbi-sg.id]
  subnet_id              = aws_subnet.sbi-public-subnet.id

  tags = {
    Name = "Web-instance"
  }
}

#creation of private-instance
resource "aws_instance" "DB-instance" {
  ami                    = "ami-0d2017e886fc2c0ab"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.sbi-deployer.key_name
  vpc_security_group_ids = [aws_security_group.sbi-sg.id]
  subnet_id              = aws_subnet.sbi-private-subnet.id
  tags = {
    Name = "DB-instance"
  }
}
