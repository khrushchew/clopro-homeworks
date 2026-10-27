terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.87"
    }
  }
  required_version = ">= 1.3"
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}

# ──────────────────────────────────────────
# VPC & Public subnet (переиспользуем из 15.2)
# ──────────────────────────────────────────
data "yandex_vpc_network" "main" {
  name = "netology-vpc-15-2"
}

data "yandex_vpc_subnet" "public" {
  name = "public-subnet"
}

# ──────────────────────────────────────────
# Service Account for Instance Group
# ──────────────────────────────────────────
resource "yandex_iam_service_account" "ig_sa" {
  name        = "ig-service-account-153"
  description = "Service account for instance group"
}

resource "yandex_resourcemanager_folder_iam_member" "ig_sa_editor" {
  folder_id = var.yc_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.ig_sa.id}"
}

# ──────────────────────────────────────────
# KMS Symmetric Key for bucket encryption
# ──────────────────────────────────────────
resource "yandex_kms_symmetric_key" "bucket_key" {
  name              = var.kms_key_name
  description       = "KMS key for Object Storage bucket encryption"
  default_algorithm = "AES_256"
  rotation_period   = "8760h"
}

# ──────────────────────────────────────────
# Object Storage (S3) — bucket + picture
# ──────────────────────────────────────────
resource "yandex_iam_service_account" "storage_sa" {
  name        = "storage-service-account-153"
  description = "Service account for object storage"
}

resource "yandex_resourcemanager_folder_iam_member" "storage_sa_admin" {
  folder_id = var.yc_folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.storage_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "storage_sa_kms" {
  folder_id = var.yc_folder_id
  role      = "kms.keys.encrypterDecrypter"
  member    = "serviceAccount:${yandex_iam_service_account.storage_sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "storage_sa_key" {
  service_account_id = yandex_iam_service_account.storage_sa.id
  description        = "Static access key for object storage"
}

resource "yandex_storage_bucket" "netology_bucket" {
  bucket     = var.bucket_name
  access_key = yandex_iam_service_account_static_access_key.storage_sa_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.storage_sa_key.secret_key

  anonymous_access_flags {
    read        = true
    list        = false
    config_read = false
  }

  # Шифрование содержимого бакета с помощью KMS ключа
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.bucket_key.id
        sse_algorithm     = "aws:kms"
      }
    }
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.storage_sa_admin,
    yandex_resourcemanager_folder_iam_member.storage_sa_kms,
  ]
}

resource "yandex_storage_object" "picture" {
  bucket     = yandex_storage_bucket.netology_bucket.bucket
  key        = "netology.jpg"
  source     = "${path.module}/netology.jpg"
  access_key = yandex_iam_service_account_static_access_key.storage_sa_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.storage_sa_key.secret_key
  acl        = "public-read"

  depends_on = [yandex_storage_bucket.netology_bucket]
}


# ──────────────────────────────────────────
# Instance Group (LAMP, 3 VMs) + health check
# ──────────────────────────────────────────
resource "yandex_compute_instance_group" "lamp_group" {
  name               = "lamp-group"
  folder_id          = var.yc_folder_id
  service_account_id = yandex_iam_service_account.ig_sa.id

  instance_template {
    platform_id = "standard-v3"

    resources {
      cores         = 2
      memory        = 2
      core_fraction = 20
    }

    boot_disk {
      initialize_params {
        image_id = "fd827b91d99psvq5fjit"
        size     = 6
      }
    }

    network_interface {
      network_id = data.yandex_vpc_network.main.id
      subnet_ids = [data.yandex_vpc_subnet.public.id]
      nat        = true
    }

    metadata = {
      ssh-keys  = "ubuntu:${file(var.public_key_path)}"
      user-data = <<-EOF
        #!/bin/bash
        apt-get update -y
        echo '<html><head><title>Netology 15.3</title></head><body><h1>Hello from Netology!</h1><img src="https://storage.yandexcloud.net/${var.bucket_name}/netology.jpg" alt="Netology picture"/></body></html>' > /var/www/html/index.html
        EOF
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = [var.yc_zone]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }

  health_check {
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2

    http_options {
      port = 80
      path = "/"
    }
  }

  load_balancer {
    target_group_name        = "lamp-target-group"
    target_group_description = "LAMP instance group target"
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.ig_sa_editor,
    yandex_storage_object.picture,
  ]
}

# ──────────────────────────────────────────
# Network Load Balancer
# ──────────────────────────────────────────
resource "yandex_lb_network_load_balancer" "lamp_nlb" {
  name = "lamp-nlb"

  listener {
    name        = "http-listener"
    port        = 80
    target_port = 80

    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.lamp_group.load_balancer[0].target_group_id

    healthcheck {
      name                = "http-healthcheck"
      interval            = 10
      timeout             = 5
      healthy_threshold   = 2
      unhealthy_threshold = 2

      http_options {
        port = 80
        path = "/"
      }
    }
  }

  depends_on = [yandex_compute_instance_group.lamp_group]
}
