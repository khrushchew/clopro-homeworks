output "kms_key_id" {
  description = "ID of the KMS symmetric key used for bucket encryption"
  value       = yandex_kms_symmetric_key.bucket_key.id
}

output "kms_key_name" {
  description = "Name of the KMS symmetric key"
  value       = yandex_kms_symmetric_key.bucket_key.name
}

output "bucket_name" {
  description = "Name of the encrypted Object Storage bucket"
  value       = yandex_storage_bucket.netology_bucket.bucket
}

output "bucket_url" {
  description = "Public URL of the picture in Object Storage"
  value       = "https://storage.yandexcloud.net/${var.bucket_name}/netology.jpg"
}

output "nlb_ip_address" {
  description = "External IP of the Network Load Balancer"
  value       = yandex_lb_network_load_balancer.lamp_nlb.listener[*].external_address_spec[*].address
}

output "instance_group_id" {
  description = "Instance Group ID"
  value       = yandex_compute_instance_group.lamp_group.id
}
