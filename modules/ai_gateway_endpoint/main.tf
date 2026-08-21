terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}

locals {
  primary_key_ref  = "{{secrets/${var.secret_scope}/${var.primary_key_name}}}"
  fallback_key_ref = "{{secrets/${var.secret_scope}/${var.fallback_key_name}}}"
  has_fallback     = var.fallback_model != "" && var.fallback_provider != ""

  # Served entities as data → one dynamic block wires every supported provider once.
  entities = concat(
    [{
      name     = "primary"
      provider = var.primary_provider
      model    = var.primary_model
      key_ref  = local.primary_key_ref
    }],
    local.has_fallback ? [{
      name     = "fallback"
      provider = var.fallback_provider
      model    = var.fallback_model
      key_ref  = local.fallback_key_ref
    }] : [],
  )

  # Rate limits: QPM (calls) always; TPM (tokens) only when > 0.
  rate_limits = concat(
    [
      { calls = var.endpoint_qpm, tokens = null, key = "endpoint", renewal_period = "minute" },
      { calls = var.per_user_qpm, tokens = null, key = "user", renewal_period = "minute" },
    ],
    var.endpoint_tpm > 0 ? [{ calls = null, tokens = var.endpoint_tpm, key = "endpoint", renewal_period = "minute" }] : [],
    var.per_user_tpm > 0 ? [{ calls = null, tokens = var.per_user_tpm, key = "user", renewal_period = "minute" }] : [],
  )
}

resource "databricks_model_serving" "this" {
  name             = var.endpoint_name
  description      = var.description
  budget_policy_id = var.budget_policy_id != "" ? var.budget_policy_id : null

  # Ops alerting on failed config rollouts.
  dynamic "email_notifications" {
    for_each = length(var.notification_emails) > 0 ? [1] : []
    content {
      on_update_failure = var.notification_emails
    }
  }

  ai_gateway {
    usage_tracking_config {
      enabled = true
    }

    inference_table_config {
      enabled           = true
      catalog_name      = var.catalog
      schema_name       = var.schema
      table_name_prefix = var.inference_table_prefix
    }

    dynamic "rate_limits" {
      for_each = local.rate_limits
      content {
        calls          = rate_limits.value.calls
        tokens         = rate_limits.value.tokens
        key            = rate_limits.value.key
        renewal_period = rate_limits.value.renewal_period
      }
    }

    guardrails {
      input {
        safety           = var.enable_safety
        invalid_keywords = length(var.blocked_keywords) > 0 ? var.blocked_keywords : null
        valid_topics     = length(var.allowed_topics) > 0 ? var.allowed_topics : null
        dynamic "pii" {
          for_each = var.pii_input_behavior == "NONE" ? [] : [1]
          content {
            behavior = var.pii_input_behavior
          }
        }
      }
      output {
        safety = var.enable_safety
        dynamic "pii" {
          for_each = var.pii_output_behavior == "NONE" ? [] : [1]
          content {
            behavior = var.pii_output_behavior
          }
        }
      }
    }

    fallback_config {
      enabled = local.has_fallback
    }
  }

  config {
    # One block wires every supported single-API-key provider. To add a multi-field
    # provider (amazon_bedrock / google_cloud_vertex_ai / databricks), add a matching
    # dynamic "<provider>_config" here — see README "Extending providers".
    dynamic "served_entities" {
      for_each = { for e in local.entities : e.name => e }
      content {
        name = served_entities.value.name
        external_model {
          name     = served_entities.value.model
          provider = served_entities.value.provider
          task     = "llm/v1/chat"

          dynamic "openai_config" {
            for_each = served_entities.value.provider == "openai" ? [1] : []
            content {
              openai_api_key = served_entities.value.key_ref
            }
          }
          dynamic "anthropic_config" {
            for_each = served_entities.value.provider == "anthropic" ? [1] : []
            content {
              anthropic_api_key = served_entities.value.key_ref
            }
          }
          dynamic "cohere_config" {
            for_each = served_entities.value.provider == "cohere" ? [1] : []
            content {
              cohere_api_key = served_entities.value.key_ref
            }
          }
          dynamic "palm_config" {
            for_each = served_entities.value.provider == "palm" ? [1] : []
            content {
              palm_api_key = served_entities.value.key_ref
            }
          }
          dynamic "ai21labs_config" {
            for_each = served_entities.value.provider == "ai21labs" ? [1] : []
            content {
              ai21labs_api_key = served_entities.value.key_ref
            }
          }
          # Databricks-hosted model (proxy) — keeps data in-plane, no third-party key.
          # external_model.name is the target Databricks endpoint (e.g. databricks-claude-haiku-4-5).
          dynamic "databricks_model_serving_config" {
            for_each = served_entities.value.provider == "databricks-model-serving" ? [1] : []
            content {
              databricks_workspace_url = var.databricks_workspace_url
              databricks_api_token     = served_entities.value.key_ref
            }
          }
        }
      }
    }

    traffic_config {
      routes {
        served_entity_name = "primary"
        traffic_percentage = 100
      }
      dynamic "routes" {
        for_each = local.has_fallback ? [1] : []
        content {
          served_entity_name = "fallback"
          traffic_percentage = 0
        }
      }
    }
  }

  dynamic "tags" {
    for_each = var.tags
    content {
      key   = tags.key
      value = tags.value
    }
  }
}

# Optional fine-grained access control — grant CAN_QUERY to account groups.
resource "databricks_permissions" "this" {
  count               = length(var.can_query_groups) > 0 ? 1 : 0
  serving_endpoint_id = databricks_model_serving.this.serving_endpoint_id

  dynamic "access_control" {
    for_each = var.can_query_groups
    content {
      group_name       = access_control.value
      permission_level = "CAN_QUERY"
    }
  }
}
