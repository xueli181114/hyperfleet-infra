# =============================================================================
# Pub/Sub Configuration Output (Complete Data for Helm Values)
# =============================================================================
# This output provides ALL Pub/Sub configuration data needed to construct
# Helm values for any deployment scenario (single or multi-topic).
#
# Example usage:
#   terraform output -json pubsub_config | jq '.sentinel.topics.clusters.topic_name'
#   terraform output -json pubsub_config | jq '.adapters["validation-gcp"].subscriptions'

output "pubsub_config" {
  description = "Complete Pub/Sub configuration for constructing Helm values"
  value = {
    # GCP Project
    project_id = var.project_id

    # Sentinel configuration
    # One GCP service account with publish permissions on ALL topics.
    # Deploy separate sentinel instances per resource type, each publishing to one topic.
    sentinel = {
      service_account_email = google_service_account.sentinel.email
      k8s_service_account   = var.sentinel_k8s_sa_name

      # All topics sentinel can publish to
      topics = {
        for topic_name, _ in local.topics : topic_name => {
          topic_name     = google_pubsub_topic.topics[topic_name].name
          topic_id       = google_pubsub_topic.topics[topic_name].id
          dlq_topic_name = var.enable_dead_letter ? google_pubsub_topic.dead_letter[topic_name].name : null
          resource_type  = topic_name # clusters, nodepools, etc.
        }
      }
    }

    # Adapter configurations
    # Each adapter has one GCP service account with subscribe permissions on its subscriptions.
    # An adapter may subscribe to multiple topics (e.g., validation-gcp on clusters AND nodepools).
    adapters = {
      for adapter in local.unique_adapters : adapter => {
        service_account_email = google_service_account.adapters[adapter].email

        # All subscriptions for this adapter (across all topics)
        subscriptions = {
          for key, sub in local.all_subscriptions :
          sub.topic_name => {
            topic_name        = google_pubsub_topic.topics[sub.topic_name].name
            subscription_name = google_pubsub_subscription.subscriptions[key].name
            subscription_id   = google_pubsub_subscription.subscriptions[key].id
            dlq_topic_name    = var.enable_dead_letter ? google_pubsub_topic.dead_letter[sub.topic_name].name : null
            ack_deadline      = sub.ack_deadline_seconds
          }
          if sub.adapter_name == adapter
        }
      }
    }

    # All topics (for reference)
    topics = {
      for topic_name, _ in local.topics : topic_name => {
        topic_name     = google_pubsub_topic.topics[topic_name].name
        topic_id       = google_pubsub_topic.topics[topic_name].id
        dlq_topic_name = var.enable_dead_letter ? google_pubsub_topic.dead_letter[topic_name].name : null
      }
    }
  }
}

