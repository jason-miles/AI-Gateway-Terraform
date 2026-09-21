# ===========================================================================
# Unity AI Gateway — provision N governed serving endpoints from one config.
# Add an entry to var.endpoints to scale; every endpoint gets the same
# governance guarantees via the reusable module. Feature→block map in README.
# ===========================================================================

provider "databricks" {
  host    = var.databricks_host
  profile = var.databricks_profile != "" ? var.databricks_profile : null
  # Token/OAuth come from the environment or the named profile — never from code.
}

module "endpoint" {
  source   = "./modules/ai_gateway_endpoint"
  for_each = var.endpoints

  endpoint_name = each.key
  description   = each.value.description

  catalog = var.catalog
  schema  = var.schema
  # Per-endpoint log table, derived from the endpoint name (kept UC-name-safe).
  inference_table_prefix = replace(replace(each.key, "-", "_"), ".", "_")

  secret_scope      = var.secret_scope
  primary_provider  = each.value.primary_provider
  primary_model     = each.value.primary_model
  primary_key_name  = each.value.primary_key_name
  fallback_provider = each.value.fallback_provider
  fallback_model    = each.value.fallback_model
  fallback_key_name = each.value.fallback_key_name

  primary_provider_config  = each.value.primary_provider_config
  fallback_provider_config = each.value.fallback_provider_config
  additional_fallbacks     = each.value.additional_fallbacks
  allowed_models           = var.allowed_models

  primary_traffic_percentage = each.value.primary_traffic_percentage

  endpoint_qpm = each.value.endpoint_qpm
  per_user_qpm = each.value.per_user_qpm
  endpoint_tpm = each.value.endpoint_tpm
  per_user_tpm = each.value.per_user_tpm

  enable_payload_logging = each.value.enable_payload_logging

  enable_safety       = each.value.enable_safety
  pii_input_behavior  = each.value.pii_input_behavior
  pii_output_behavior = each.value.pii_output_behavior
  blocked_keywords    = each.value.blocked_keywords
  allowed_topics      = each.value.allowed_topics

  can_query_groups         = each.value.can_query_groups
  notification_emails      = each.value.notification_emails
  databricks_workspace_url = var.databricks_host
  budget_policy_id         = each.value.budget_policy_id != "" ? each.value.budget_policy_id : var.budget_policy_id

  # Cost-attribution tag taxonomy: global tags, then canonical labels stamped on
  # every endpoint (endpoint / environment / managed_by) so usage joins cleanly to
  # system.ai_gateway.usage and Budget tag filters, then per-endpoint tags (which win).
  tags = merge(
    var.global_tags,
    {
      endpoint    = each.key
      environment = var.environment
      managed_by  = "terraform"
    },
    each.value.owner != "" ? { owner = each.value.owner } : {},
    each.value.business_unit != "" ? { business_unit = each.value.business_unit } : {},
    each.value.application != "" ? { application = each.value.application } : {},
    each.value.data_residency != "" ? { data_residency = each.value.data_residency } : {},
    each.value.tags,
  )
}

# Least-privilege read access to the inference/payload log schema (blueprint §2). Additive
# per-principal grants (non-authoritative), inert unless var.log_reader_groups is set.
resource "databricks_grant" "inference_logs" {
  for_each = toset(var.log_reader_groups)

  schema     = "${var.catalog}.${var.schema}"
  principal  = each.value
  privileges = ["USE_SCHEMA", "SELECT"]
}
