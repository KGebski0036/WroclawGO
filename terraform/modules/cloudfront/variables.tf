variable "project_name" { type = string }
variable "s3_bucket_regional_domain_name" { type = string }
variable "s3_origin_id" { type = string }
variable "waf_web_acl_arn" { type = string }
variable "geo_allowlist" { type = list(string) }
variable "log_bucket_domain_name" { type = string }
variable "response_headers_policy_id" {
  type    = string
  default = "67f7725c-6f97-4210-82d7-5512b31e9d03"
}
