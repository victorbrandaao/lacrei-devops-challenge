variable "region" {
  description = "AWS Region"
  type        = string
  default     = "sa-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "lacrei"
}

variable "container_image" {
  description = "Container image URI from ECR"
  type        = string
  default     = "428014821600.dkr.ecr.sa-east-1.amazonaws.com/lacrei-api:latest"
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 3000
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "ecs_ami_id" {
  description = "ECS-optimized AMI ID for EC2 instances"
  type        = string
  default     = "ami-02f46e3dab0c6159e"
}

variable "domain_name" {
  description = "Domain name for HTTPS (leave empty to skip HTTPS setup)"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for domain validation"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address for CloudWatch alarms"
  type        = string
  default     = "seu-email@exemplo.com"
}
