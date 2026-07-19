output "service_url" {
  description = "Cloud Run service URL."
  value       = module.katagami_stack.service_url
}

output "artifact_registry_url" {
  description = "Artifact Registry repository URL."
  value       = module.katagami_stack.artifact_registry_url
}
