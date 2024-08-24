
output "backend_service_mig" {
  description = "Backend resource."
  value       = try(google_compute_backend_service.mig, null)
}

output "backend_service_neg" {
  description = "Backend resource."
  value       = try(google_compute_backend_service.neg, null)
}

output "backend_service_psc_neg" {
  description = "Backend resource."
  value       = try(google_compute_backend_service.psc_neg, null)
}
