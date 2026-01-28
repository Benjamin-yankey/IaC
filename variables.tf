variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "availability_zone" {
  description = "AZ"
  type        = string
  default     = "eu-west-1a"
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "my_ip" {
  description = "Your public IP for SSH access"
  type        = string
}
