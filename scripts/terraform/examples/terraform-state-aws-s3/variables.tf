variable "terraform_state_bucket_name" {
  description = "The S3 bucket name to store Terraform state"
  default     = "repository-template-example-terraform-state-store"
}

variable "terraform_state_table_name" {
  description = "The DynamoDB table name to acquire Terraform lock"
  default     = "repository-template-example-terraform-state-lock"
}
