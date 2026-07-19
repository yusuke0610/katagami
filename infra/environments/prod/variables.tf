variable "environment" {
  description = "Environment name (dev / stg / prod)."
  type        = string
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "app_name" {
  description = "Application name. Used as the stack name prefix."
  type        = string
  default     = "katagami"
}

variable "region" {
  description = "GCP region."
  type        = string
  default     = "asia-northeast1"
}

variable "deployer_service_account_email" {
  description = "Optional deployer (CI) service account email."
  type        = string
  default     = ""
}

variable "cors_origins" {
  description = "Comma-separated allowed CORS origins."
  type        = string
}
