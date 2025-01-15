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


