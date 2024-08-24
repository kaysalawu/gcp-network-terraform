
output "forwarding_rule_https" {
  description = "Forwarding rule resource."
  value       = google_compute_forwarding_rule.https
}
