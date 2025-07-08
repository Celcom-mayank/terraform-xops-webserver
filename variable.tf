variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"   # Mumbai; change if you wish
}

variable "key_pair_name" {
  description = "Existing EC2 key pair for SSH access"
  type        = string
}
