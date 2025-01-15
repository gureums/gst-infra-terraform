terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
}

# VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "gureum-vpc-terraform"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "gureum-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnets" {
  for_each               = toset(var.public_subnet_cidr)
  vpc_id                 = aws_vpc.main_vpc.id
  cidr_block             = each.key
  availability_zone      = element(var.availability_zone, index(var.public_subnet_cidr, each.key))
  map_public_ip_on_launch = true
  tags = {
    Name = "Public-Subnet-${element(var.availability_zone, index(var.public_subnet_cidr, each.key))}"
  }
}

# NAT Gateway Elastic IPs
resource "aws_eip" "nat_eips" {
  for_each = toset(var.availability_zone)
  tags = {
    Name = "NAT-EIP-${each.value}"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "nat_gateways" {
  for_each         = aws_eip.nat_eips
  allocation_id    = each.value.id
  subnet_id        = element([for subnet in aws_subnet.public_subnets : subnet.id if subnet.availability_zone == each.key], 0)
  tags = {
    Name = "NAT-Gateway-${each.key}"
  }
}

# Private Subnets
resource "aws_subnet" "private_general_subnets" {
  for_each               = toset(var.private_subnet_general_cidr)
  vpc_id                 = aws_vpc.main_vpc.id
  cidr_block             = each.key
  availability_zone      = element(var.availability_zone, index(var.private_subnet_general_cidr, each.key))
  tags = {
    Name = "Private-General-Subnet-${element(var.availability_zone, index(var.private_subnet_general_cidr, each.key))}"
  }
}

# RDS Private Subnets
resource "aws_subnet" "private_rds_subnets" {
  for_each               = toset(var.private_subnet_rds_cidr)
  vpc_id                 = aws_vpc.main_vpc.id
  cidr_block             = each.key
  availability_zone      = element(var.availability_zone, index(var.private_subnet_rds_cidr, each.key))
  tags = {
    Name = "Private-RDS-Subnet-${element(var.availability_zone, index(var.private_subnet_rds_cidr, each.key))}"
  }
}

# ElastiCache Private Subnets
resource "aws_subnet" "private_elasticache_subnets" {
  for_each               = toset(var.private_subnet_elasticache_cidr)
  vpc_id                 = aws_vpc.main_vpc.id
  cidr_block             = each.key
  availability_zone      = element(var.availability_zone, index(var.private_subnet_elasticache_cidr, each.key))
  tags = {
    Name = "Private-ElastiCache-Subnet-${element(var.availability_zone, index(var.private_subnet_elasticache_cidr, each.key))}"
  }
}

# Public Subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
      Name = "Public-Route-Table"
  }
}

# Public Subnet Association
resource "aws_route_table_association" "public_subnet_associations" {
  for_each = aws_subnet.public_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}

# Private Subnet
resource "aws_route_table" "private_route_table" {
  for_each = aws_nat_gateway.nat_gateways

  vpc_id = aws_vpc.main_vpc.id

  route {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = each.value.id
  }

  tags = {
      Name = "Private-Route-Table-${each.key}"
  }
}

# Private Subnet Association
resource "aws_route_table_association" "private_subnet_associations" {
  for_each = aws_subnet.private_general_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table[element(var.availability_zone, index(var.private_subnet_general_cidr, each.key))].id
}