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

output "target_group_id" {
  description = "NLB Target Group ID"
  value       = yandex_compute_instance_group.lamp_group.load_balancer[0].target_group_id
}
