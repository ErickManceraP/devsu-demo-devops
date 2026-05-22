variable "aws_region" {
  description = "AWS region where the infrastructure will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "devsu-demo-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.small"
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 5
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "app_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "devsu-demo"
}

variable "app_image" {
  description = "Docker image for the application (e.g. ghcr.io/user/repo:tag)"
  type        = string
  default     = "ghcr.io/your-user/devsu-demo-devops-nodejs:latest"
}

variable "db_user" {
  description = "SQLite database user (stored as K8s Secret)"
  type        = string
  default     = "user"
  sensitive   = true
}

variable "db_password" {
  description = "SQLite database password (stored as K8s Secret)"
  type        = string
  default     = "password"
  sensitive   = true
}

variable "tags" {
  description = "Common tags applied to all AWS resources"
  type        = map(string)
  default = {
    Project     = "devsu-demo-devops"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
