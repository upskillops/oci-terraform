variable "tenancy_ocid" { type = string }
variable "compartment_id" { type = string }
variable "name" {
  type        = string
  description = "Name for the IAM user and group."
}
variable "bucket_names" {
  type        = list(string)
  description = "Buckets the user may read and write."
}
variable "tags" { type = map(string) }
variable "email" {
  type        = string
  description = "Email for the IAM user (required in identity-domain tenancies)."
}
