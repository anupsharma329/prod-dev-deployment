
variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "List of CIDR blocks for subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "active_target" {
  description = "The active target group (prod or dev) - controls which environment receives traffic"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod", "dev"], var.active_target)
    error_message = "active_target must be either 'prod' or 'dev'."
  }
}

