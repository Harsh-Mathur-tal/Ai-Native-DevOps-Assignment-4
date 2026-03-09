output "namespace" {
  description = "The namespace created for the API platform"
  value       = kubernetes_namespace.api_platform.metadata[0].name
}
