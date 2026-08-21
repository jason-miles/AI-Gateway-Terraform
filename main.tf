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

  endpoint_qpm = each.value.endpoint_qpm
  per_user_qpm = each.value.per_user_qpm
  endpoint_tpm = each.value.endpoint_tpm
  per_user_tpm = each.value.per_user_tpm

  enable_safety       = each.value.enable_safety
  pii_input_behavior  = each.value.pii_input_behavior
  pii_output_behavior = each.value.pii_output_behavior
  blocked_keywords    = each.value.blocked_keywords
  allowed_topics      = each.value.allowed_topics

  can_query_groups         = each.value.can_query_groups
  notification_emails      = each.value.notification_emails
  databricks_workspace_url = var.databricks_host
  budget_policy_id         = each.value.budget_policy_id != "" ? each.value.budget_policy_id : var.budget_policy_id

  # Global tags + standard labels + per-endpoint tags (per-endpoint wins).
  tags = merge(
    var.global_tags,
    { environment = var.environment, managed_by = "terraform" },
    each.value.tags,
  )
}
