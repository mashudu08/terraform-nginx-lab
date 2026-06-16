terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  # Uses default Docker socket - no config needed if Docker is running
}

resource "random_pet" "server_name" {
  length    = 2
  separator = "-"
}

resource "random_uuid" "server_id" {}

resource "local_file" "inventory" {
  filename = "${path.module}/inventory.json"
  content = jsonencode({
    server_name = random_pet.server_name.id
    server_uuid = random_uuid.server_id.id
    environment = "prod-local"
    deployed_at = timestamp()
  })
}

output "server_name" {
  value = random_pet.server_name.id
}

output "inventory_file_path" {
  value = local_file.inventory.filename
}

# ============================================
# Docker Resources
# ============================================

# Pull an Nginx image
data "docker_image" "nginx" {
  name = "nginx:latest"
}

# Run Nginx container
resource "docker_container" "web_server" {
  name  = "terraform-nginx-${random_pet.server_name.id}"
  image = data.docker_image.nginx.name

  ports {
    internal = 80
    external = 8081
  }

  # Health check
  healthcheck {
    test     = ["CMD", "curl", "-f", "http://localhost/"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }

  # Labels
  labels {
    label = "managed_by"
    value = "terraform"
  }
  labels {
    label = "server_id"
    value = random_uuid.server_id.id
  }
  labels {
    label = "env"
    value = "dev_local"
  }
}

# Test the container after it's created
resource "null_resource" "test_nginx" {
  depends_on = [docker_container.web_server]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Testing Nginx container..."
      sleep 2
      curl -s http://localhost:8080 | head -n 5
      echo "Container is running! ✓"
    EOT
  }

  triggers = {
    container_id = docker_container.web_server.id
  }
}

# Capture container logs
resource "null_resource" "capture_logs" {
  depends_on = [docker_container.web_server]

  provisioner "local-exec" {
    command = <<-EOT
      docker logs $(docker ps -q --filter "name=terraform-nginx-*") > nginx-logs.txt
      echo "Logs captured at $(date)" >> nginx-logs.txt
    EOT
  }

  triggers = {
    container_id = docker_container.web_server.id
    timestamp    = timestamp()
  }
}

output "container_id" {
  value = docker_container.web_server.id
}

output "nginx_url" {
  value = "http://localhost:8080"
}