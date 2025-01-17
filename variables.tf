variable "region" {
  default = "ap-northeast-2"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "availability_zone" {
  default = ["ap-northeast-2a", "ap-northeast-2b"]
}

variable "public_subnet_cidr" {
  default = ["10.0.0.0/20", "10.0.16.0/20"]
}

variable "private_subnet_general_cidr" {
  default = ["10.0.32.0/20", "10.0.48.0/20"]
}

variable "private_subnet_rds_cidr" {
  default = ["10.0.64.0/24", "10.0.80.0/24"]
}

variable "private_subnet_elasticache_cidr" {
  default = ["10.0.96.0/24", "10.0.112.0/24"]
}

variable "bucket_s3_dirs" {
  default = ["dags/", "scripts/", "data/", "logs/"]
}