# =============================================================================
# Topic Outputs
# =============================================================================
output "topic_name" {
  description = "Name of the Pub/Sub topic"
  value       = google_pubsub_topic.events.name
}

output "topic_id" {
  description = "Full ID of the Pub/Sub topic"
  value       = google_pubsub_topic.events.id
}

output "dlq_topic_name" {
  description = "Name of the dead letter topic (null when DLQ is disabled)"
  value       = var.enable_dead_letter ? google_pubsub_topic.dead_letter[0].name : null
}

# =============================================================================
# Subscription Outputs
# =============================================================================
output "subscriptions" {
  description = "Map of adapter names to their subscription details"
  value = {
    for adapter, config in local.adapter_configs : adapter => {
      name = google_pubsub_subscription.adapters[adapter].name
      id   = google_pubsub_subscription.adapters[adapter].id
    }
  }
}

output "subscription_names" {
  description = "List of all adapter subscription names"
  value       = [for adapter in var.adapters : google_pubsub_subscription.adapters[adapter].name]
}

# =============================================================================
# Service Account Outputs
# =============================================================================
output "sentinel_service_account_email" {
  description = "Email of the Sentinel GCP service account"
  value       = google_service_account.sentinel.email
}

output "adapter_service_accounts" {
  description = "Map of adapter names to their GCP service account emails"
  value = {
    for adapter in var.adapters : adapter => google_service_account.adapters[adapter].email
  }
}

# =============================================================================
# Helm Values Snippet
# =============================================================================
output "helm_values_snippet" {
  description = "Snippet to add to Helm values for Workload Identity annotations"
  value       = <<-EOT
    # Add these annotations to your Helm values:

    # For Sentinel:
    sentinel:
      serviceAccount:
        annotations:
          iam.gke.io/gcp-service-account: ${google_service_account.sentinel.email}
      broker:
        type: googlepubsub
        topic: ${google_pubsub_topic.events.name}
        googlepubsub:
          projectId: ${var.project_id}
          createTopicIfMissing: false

    # For Adapters:
    %{for adapter in var.adapters~}
    ${adapter}-adapter:
      serviceAccount:
        name: ${local.adapter_configs[adapter].k8s_service_account_name}
        annotations:
          iam.gke.io/gcp-service-account: ${google_service_account.adapters[adapter].email}
      broker:
        type: googlepubsub
        subscriptionId: ${google_pubsub_subscription.adapters[adapter].name}
        topic: ${google_pubsub_topic.events.name}
        googlepubsub:
          projectId: ${var.project_id}
          createSubscriptionIfMissing: false

    %{endfor~}
  EOT
}
