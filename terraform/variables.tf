variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}
variable "db_password" {
  description = "RDS master password - NEVER commit real value, use tfvars / Secrets Manager for prod"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}
