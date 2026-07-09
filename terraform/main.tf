terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "Binome-ISI"
  }
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS Region to deploy resources"
}

variable "project_name" {
  type        = string
  default     = "petclinic"
  description = "Name of the project"
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Deployment environment"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC"
}

variable "availability_zones" {
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  description = "List of availability zones"
}

variable "ec2_instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for PetClinic"
}

variable "db_instance_class" {
  type        = string
  default     = "db.t3.micro"
  description = "RDS DB instance class"
}

variable "ec2_ami_id" {
  type        = string
  default     = "ami-0c7217cdde317cfec" # Standard Amazon Linux 2023 AMI in us-east-1
  description = "Hardcoded AMI ID to bypass EC2:DescribeImages restrictions"
}

