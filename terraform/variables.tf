variable "aws_region" { default = "eu-central-1" }
variable "project_name" { default = "wroclawgo" }
variable "environment" { default = "prod" }
variable "geo_allowlist" {
  type    = list(string)
  default = ["PL", "DE", "CZ"]
}
variable "sse_kms_key_id" {
  type    = string
  default = "alias/aws/s3"
}
variable "log_retention_days" {
  type    = number
  default = 90
}
variable "response_headers_policy_id" {
  type    = string
  default = "67f7725c-6f97-4210-82d7-5512b31e9d03"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "db_name" {
  type    = string
  default = "wroclawgo"
}

variable "db_username" {
  type    = string
  default = "wroclawgo_user"
}

variable "admin_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "backend_image_tag" {
  type    = string
  default = "latest"
}

variable "backend_instance_type" {
  type    = string
  default = "t3.micro"
}
