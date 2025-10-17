variable "region" {
  type    = string
  default = "sa-east-1"
}

variable "project_name" {
  type    = string
  default = "lacrei"
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "domain_name" {
  type    = string
  default = ""
}

variable "hosted_zone_id" {
  type    = string
  default = ""
}

variable "container_image" {
  type    = string
  default = "428014821600.dkr.ecr.sa-east-1.amazonaws.com/lacrei-api:latest"
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "ecs_ami_id" {
  type    = string
  default = "ami-02f46e3dab0c6159e"
}
