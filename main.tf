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
    Name = "IGW"
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

# RDS Subnet Group
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [for subnet in aws_subnet.private_rds_subnets : subnet.id]
  
  tags = {
    Name = "RDS-Subnet-Group"
  }
}

# RDS Instance
resource "aws_db_instance" "rds_instance" {
  identifier           = "rds-instance"
  allocated_storage    = 200
  engine               = "postgres"
  engine_version       = "16.3"
  instance_class       = "db.t4g.micro"
  username             = "Airflow"
  password             = "Airflow123!"
  parameter_group_name = "default.postgres16"
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]


  publicly_accessible = false
  skip_final_snapshot = true

  tags = {
    Name = "Airflow-MetaDB"
  }
}

# RDS Security Group
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # VPC CIDR 블록
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS-Security-Group"
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

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "elasticache_subnet_group" {
  name       = "elasticache-subnet-group"
  subnet_ids = [for subnet in aws_subnet.private_elasticache_subnets : subnet.id]
  
  tags = {
    Name = "ElastiCache-Subnet-Group"
  }
}

# ElastiCache Cluster
resource "aws_elasticache_cluster" "elasticache_cluster" {
  cluster_id           = "my-elasticache-cluster"
  engine               = "redis"
  node_type            = "cache.t4g.medium"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  subnet_group_name    = aws_elasticache_subnet_group.elasticache_subnet_group.name
  security_group_ids   = [aws_security_group.elasticache_sg.id]

  tags = {
    Name = "Airflow-Message-Broker"
  }
}

# ElastiCache Security Group
resource "aws_security_group" "elasticache_sg" {
  name        = "elasticache-sg"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # VPC CIDR 블록
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ElastiCache-Security-Group"
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

# S3
resource "aws_s3_bucket" "bucket_airflow" {
  bucket = "airflow-datalake-s3"

  tags = {
    Name = "Airflow Bucket"
  }
}

# S3 Public Access
resource "aws_s3_bucket_public_access_block" "public-access" {
  bucket = aws_s3_bucket.bucket_airflow.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Policy
resource "aws_s3_bucket_policy" "bucket-policy" {
  bucket = aws_s3_bucket.bucket_airflow.id

  depends_on = [
    aws_s3_bucket_public_access_block.public-access
  ]

  policy = <<POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::${aws_s3_bucket.bucket_airflow.id}/*"
        }
    ]
  }
  POLICY
}

# S3 Resource Folder Set
resource "aws_s3_object" "s3-upload-resource-dirs" {
  for_each = toset(var.bucket_s3_dirs)
  bucket = aws_s3_bucket.bucket_airflow.id
  key    = each.key
  source = ""
}