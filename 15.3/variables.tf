variable "yc_token" {
  description = "Yandex Cloud IAM token (yc iam create-token)"
  type        = string
  sensitive   = true
}

variable "yc_cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
  default     = "b1g03cqd7ovsppviksle"
}

variable "yc_folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
  default     = "b1ggjssjqp3mfsai4u7k"
}

variable "yc_zone" {
  description = "Yandex Cloud availability zone"
  type        = string
  default     = "ru-central1-a"
}

variable "public_key_path" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "bucket_name" {
  description = "Name for the Object Storage bucket (must be globally unique)"
  type        = string
  default     = "khrushchew-20261027"
}

variable "kms_key_name" {
  description = "Name of the KMS symmetric key for bucket encryption"
  type        = string
  default     = "netology-bucket-key"
}
