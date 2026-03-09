# Terraform configuration for Kubernetes infrastructure
# Note: This assumes Minikube is already running
# For production, this would provision the cluster itself

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

# Create namespace for the API platform
# Note: If namespace already exists, Terraform will import it on next apply
resource "kubernetes_namespace" "api_platform" {
  metadata {
    name = "api-platform"
    labels = {
      name        = "api-platform"
      environment = "development"
    }
  }
  
  lifecycle {
    # Ignore changes to prevent conflicts if namespace is modified outside Terraform
    ignore_changes = [metadata[0].annotations]
  }
}

# Network Policy for basic network segmentation
resource "kubernetes_network_policy" "api_platform" {
  metadata {
    name      = "api-platform-network-policy"
    namespace = kubernetes_namespace.api_platform.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "kong"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "api-platform"
          }
        }
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "api-platform"
          }
        }
      }
    }
  }
  
  depends_on = [kubernetes_namespace.api_platform]
}
