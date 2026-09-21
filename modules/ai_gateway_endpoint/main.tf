terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.60.0, < 2.0.0"
    }
  }
}

locals {
  primary_key_ref  = "{{secrets/${var.secret_scope}/${var.primary_key_name}}}"
  fallback_key_ref = "{{secrets/${var.secret_scope}/${var.fallback_key_name}}}"
  has_fallback     = var.fallback_model != "" && var.fallback_provider != ""

  # Map module-facing provider aliases → the value the databricks provider expects on
  # external_model.provider. Aliases keep credential handling explicit:
  #   azure-openai     → openai   (with openai_api_type = "azure")
  #   google-vertex-ai → google-cloud-vertex-ai
  # Unlisted providers pass through unchanged.
  provider_api = {
    "azure-openai"     = "openai"
    "google-vertex-ai" = "google-cloud-vertex-ai"
  }

  # Served entities as data → one dynamic block per provider wires them once.
  entities = concat(
    [{
      name         = "primary"
      provider     = var.primary_provider
      api_provider = lookup(local.provider_api, var.primary_provider, var.primary_provider)
      model        = var.primary_model
      key_ref      = local.primary_key_ref
      cfg          = var.primary_provider_config
    }],
    local.has_fallback ? [{
      name         = "fallback"
      provider     = var.fallback_provider
      api_provider = lookup(local.provider_api, var.fallback_provider, var.fallback_provider)
      model        = var.fallback_model
      key_ref      = local.fallback_key_ref
      cfg          = var.fallback_provider_config
    }] : [],
    # Ordered additional fallbacks (fallback-2, fallback-3, …) — tried in list order on error.
    [for i, f in var.additional_fallbacks : {
      name         = "fallback-${i + 2}"
      provider     = f.provider
      api_provider = lookup(local.provider_api, f.provider, f.provider)
      model        = f.model
      key_ref      = "{{secrets/${var.secret_scope}/${f.key_name}}}"
      cfg          = f.provider_config
    }],
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

    # Payload/inference logging is opt-in per endpoint. Best practice (Unity Gateway
    # blueprint): enable only where request/response auditing or debugging is justified,
    # with access + retention controls. Usage-metric tracking above stays on regardless.
    inference_table_config {
      enabled           = var.enable_payload_logging
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
    # One dynamic block per supported provider; each fires only for its own entities.
    # Key-only providers use just key_ref; multi-field providers (Bedrock / Vertex /
    # Azure OpenAI) also read *_provider_config. To add another, append a matching
    # dynamic "<provider>_config" — see README "Extending providers".
    dynamic "served_entities" {
      for_each = { for e in local.entities : e.name => e }
      content {
        name = served_entities.value.name
        external_model {
          name     = served_entities.value.model
          provider = served_entities.value.api_provider
          task     = "llm/v1/chat"

          # openai + azure-openai (Azure adds api_type/base/deployment/version).
          dynamic "openai_config" {
            for_each = contains(["openai", "azure-openai"], served_entities.value.provider) ? [1] : []
            content {
              openai_api_key         = served_entities.value.key_ref
              openai_api_type        = served_entities.value.provider == "azure-openai" ? "azure" : null
              openai_api_base        = served_entities.value.cfg.openai_api_base != "" ? served_entities.value.cfg.openai_api_base : null
              openai_deployment_name = served_entities.value.cfg.openai_deployment_name != "" ? served_entities.value.cfg.openai_deployment_name : null
              openai_api_version     = served_entities.value.cfg.openai_api_version != "" ? served_entities.value.cfg.openai_api_version : null
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
          # Amazon Bedrock — role-based (instance_profile_arn) or static keys.
          dynamic "amazon_bedrock_config" {
            for_each = served_entities.value.provider == "amazon-bedrock" ? [1] : []
            content {
              aws_region       = served_entities.value.cfg.aws_region
              bedrock_provider = served_entities.value.cfg.bedrock_provider
              # Role-based when an instance profile is given; otherwise static keys
              # (access key id from a secret, secret access key from the entity key).
              instance_profile_arn  = served_entities.value.cfg.instance_profile_arn != "" ? served_entities.value.cfg.instance_profile_arn : null
              aws_access_key_id     = served_entities.value.cfg.aws_access_key_name != "" ? "{{secrets/${var.secret_scope}/${served_entities.value.cfg.aws_access_key_name}}}" : null
              aws_secret_access_key = served_entities.value.cfg.instance_profile_arn == "" ? served_entities.value.key_ref : null
            }
          }
          # Google Cloud Vertex AI — service-account private key (secret ref).
          dynamic "google_cloud_vertex_ai_config" {
            for_each = served_entities.value.provider == "google-vertex-ai" ? [1] : []
            content {
              project_id  = served_entities.value.cfg.vertex_project_id
              region      = served_entities.value.cfg.vertex_region
              private_key = served_entities.value.key_ref
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

    # Steady-state traffic split. With no fallback, primary takes 100%.
    # With a fallback, primary_traffic_percentage controls the split:
    #   100        → active/passive failover only (fallback gets traffic on error)
    #   <100 (e.g. 80) → load-balance across primary + fallback (80/20 steady state)
    traffic_config {
      routes {
        served_entity_name = "primary"
        traffic_percentage = local.has_fallback ? var.primary_traffic_percentage : 100
      }
      dynamic "routes" {
        for_each = local.has_fallback ? [1] : []
        content {
          served_entity_name = "fallback"
          traffic_percentage = 100 - var.primary_traffic_percentage
        }
      }
      # Additional fallbacks carry 0% steady-state traffic; they receive requests only via
      # error-failover (fallback_config), in list order after the first fallback.
      dynamic "routes" {
        for_each = var.additional_fallbacks
        iterator = f
        content {
          served_entity_name = "fallback-${f.key + 2}"
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
