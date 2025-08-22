variable "domain_name" {
  description = "Domain name for SES"
  type        = string
}

variable "email_from" {
  description = "From email address"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}