# Get current project info for service account references
data "google_project" "current" {
  project_id = var.project_id
}

# =============================================================================
# Workload Identity Federation Principal Prefix
# =============================================================================
locals {
  # Common WIF principal prefix for all Kubernetes service accounts
  wif_principal_prefix = "principal://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/${var.kubernetes_namespace}/sa/"
}

# =============================================================================
# Publisher Workload Identity - Grant permissions to publishers on their topics
# =============================================================================
# Grant publisher permissions to topics using WIF principals
# This dynamically assigns roles based on the publishers configuration
resource "google_pubsub_topic_iam_member" "publishers" {
  for_each = local.all_publisher_roles

  topic   = google_pubsub_topic.topics[each.value.topic_name].name
  role    = each.value.role
  member  = "${local.wif_principal_prefix}${each.value.publisher_name}"
  project = var.project_id
}

# =============================================================================
# Adapter Workload Identity (Subscribers)
# =============================================================================
# Grant Adapter permissions to their subscriptions using WIF principals
# This dynamically assigns roles based on the subscriptions configuration
resource "google_pubsub_subscription_iam_member" "adapters" {
  for_each = local.all_subscription_roles

  subscription = google_pubsub_subscription.subscriptions[each.value.subscription_key].name
  role         = each.value.role
  member       = "${local.wif_principal_prefix}${each.value.adapter_name}-adapter"
  project      = var.project_id
}

# =============================================================================
# Dead Letter Queue Permissions (if enabled)
# =============================================================================

# Grant Pub/Sub service account permission to publish to DLQ topics
# This is required for the dead letter policy to work
resource "google_pubsub_topic_iam_member" "pubsub_dlq_publisher" {
  for_each = var.enable_dead_letter ? local.topics : {}

  topic   = google_pubsub_topic.dead_letter[each.key].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  project = var.project_id
}

# Grant Pub/Sub service account permission to acknowledge messages from all subscriptions
resource "google_pubsub_subscription_iam_member" "pubsub_dlq_subscriber" {
  for_each = var.enable_dead_letter ? local.all_subscriptions : {}

  subscription = google_pubsub_subscription.subscriptions[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  project      = var.project_id
}
