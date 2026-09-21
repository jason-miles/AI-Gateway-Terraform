# ---------------------------------------------------------------------------
# Connection & auth (no credentials stored here)
# ---------------------------------------------------------------------------
variable "databricks_host" {
  type        = string
  description = "Workspace URL, e.g. https://<name>.cloud.databricks.com. Auth via env/CLI (DATABRICKS_TOKEN or a CLI profile) — never tokens in code."
}

variable "databricks_profile" {
  type        = string
  description = "Optional ~/.databrickscfg profile name to authenticate with. Leave \"\" to use env vars / default auth."
  default     = ""
}

# ---------------------------------------------------------------------------
# Global defaults (apply to every endpoint unless overridden)
# ---------------------------------------------------------------------------
variable "catalog" {
  type        = string
  description = "Unity Catalog catalog for inference logs. Must exist and be writable."
  default     = "main"
}

variable "schema" {
  type        = string
  description = "Unity Catalog schema for inference logs. Must exist."
  default     = "ai_gateway"
}

variable "secret_scope" {
  type        = string
  description = "Databricks secret scope holding provider API keys (create out-of-band; see README)."
  default     = "ai_gateway"
}

variable "environment" {
  type        = string
  description = "Deployment environment label, applied as a tag and available for naming conventions."
  default     = "dev"
}

variable "budget_policy_id" {
  type        = string
  description = "Optional default UC budget policy id applied to every endpoint (\"\" = none). Per-endpoint value overrides."
  default     = ""
}

variable "global_tags" {
  type        = map(string)
  description = "Tags applied to every endpoint (merged with per-endpoint tags; per-endpoint wins)."
  default     = {}
}

# ---------------------------------------------------------------------------
# The endpoints to manage. Map key = endpoint name. Scale by adding entries.
# Every field is optional and inherits a sensible default.
# ---------------------------------------------------------------------------
variable "endpoints" {
  description = "Map of governed AI Gateway endpoints to provision (key = endpoint name)."
  type = map(object({
    description       = optional(string, "Governed AI Gateway endpoint")
    owner             = optional(string, "") # service owner (email or group); stamped as an `owner` tag when set
    primary_provider  = optional(string, "openai")
    primary_model     = optional(string, "gpt-4o")
    primary_key_name  = optional(string, "openai_api_key")
    fallback_provider = optional(string, "anthropic")
    fallback_model    = optional(string, "")
    fallback_key_name = optional(string, "anthropic_api_key")

    # Provider-specific config for Bedrock / Vertex / Azure OpenAI (all fields optional).
    primary_provider_config = optional(object({
      aws_region             = optional(string, "")
      bedrock_provider       = optional(string, "")
      aws_access_key_name    = optional(string, "")
      instance_profile_arn   = optional(string, "")
      vertex_project_id      = optional(string, "")
      vertex_region          = optional(string, "")
      openai_api_base        = optional(string, "")
      openai_deployment_name = optional(string, "")
      openai_api_version     = optional(string, "")
    }), {})
    fallback_provider_config = optional(object({
      aws_region             = optional(string, "")
      bedrock_provider       = optional(string, "")
      aws_access_key_name    = optional(string, "")
      instance_profile_arn   = optional(string, "")
      vertex_project_id      = optional(string, "")
      vertex_region          = optional(string, "")
      openai_api_base        = optional(string, "")
      openai_deployment_name = optional(string, "")
      openai_api_version     = optional(string, "")
    }), {})

    # Ordered additional fallbacks (beyond the first) — tried in order on 429/5XX. Requires a first fallback.
    additional_fallbacks = optional(list(object({
      provider = string
      model    = string
      key_name = string
      provider_config = optional(object({
        aws_region             = optional(string, "")
        bedrock_provider       = optional(string, "")
        aws_access_key_name    = optional(string, "")
        instance_profile_arn   = optional(string, "")
        vertex_project_id      = optional(string, "")
        vertex_region          = optional(string, "")
        openai_api_base        = optional(string, "")
        openai_deployment_name = optional(string, "")
        openai_api_version     = optional(string, "")
      }), {})
    })), [])

    # Steady-state split across primary + fallback. 100 = failover only; <100 = load-balance.
    primary_traffic_percentage = optional(number, 100)

    endpoint_qpm           = optional(number, 500)
    per_user_qpm           = optional(number, 50)
    endpoint_tpm           = optional(number, 0)
    per_user_tpm           = optional(number, 0)
    enable_payload_logging = optional(bool, true) # full request/response logging (blueprint: only where justified)
    enable_safety          = optional(bool, true)
    pii_input_behavior     = optional(string, "BLOCK")
    pii_output_behavior    = optional(string, "MASK")
    blocked_keywords       = optional(list(string), [])
    allowed_topics         = optional(list(string), [])
    can_query_groups       = optional(list(string), [])
    budget_policy_id       = optional(string, "")
    tags                   = optional(map(string), {})
    notification_emails    = optional(list(string), [])
  }))

  validation {
    condition = alltrue([
      for e in values(var.endpoints) :
      contains(["openai", "azure-openai", "anthropic", "cohere", "palm", "ai21labs", "amazon-bedrock", "google-vertex-ai", "databricks-model-serving"], e.primary_provider) &&
      (e.fallback_model == "" || contains(["openai", "azure-openai", "anthropic", "cohere", "palm", "ai21labs", "amazon-bedrock", "google-vertex-ai", "databricks-model-serving"], e.fallback_provider))
    ])
    error_message = "primary_provider / fallback_provider must be one of: openai, azure-openai, anthropic, cohere, palm, ai21labs, amazon-bedrock, google-vertex-ai, databricks-model-serving."
  }

  # Multi-field providers require their config fields to be set.
  validation {
    condition = alltrue([
      for e in values(var.endpoints) :
      (e.primary_provider != "amazon-bedrock" || (e.primary_provider_config.aws_region != "" && e.primary_provider_config.bedrock_provider != "")) &&
      (e.primary_provider != "google-vertex-ai" || (e.primary_provider_config.vertex_project_id != "" && e.primary_provider_config.vertex_region != "")) &&
      (e.fallback_provider != "amazon-bedrock" || e.fallback_model == "" || (e.fallback_provider_config.aws_region != "" && e.fallback_provider_config.bedrock_provider != "")) &&
      (e.fallback_provider != "google-vertex-ai" || e.fallback_model == "" || (e.fallback_provider_config.vertex_project_id != "" && e.fallback_provider_config.vertex_region != ""))
    ])
    error_message = "amazon-bedrock requires provider_config.aws_region + bedrock_provider; google-vertex-ai requires provider_config.vertex_project_id + vertex_region."
  }

  validation {
    condition = alltrue([
      for e in values(var.endpoints) :
      contains(["NONE", "BLOCK", "MASK"], e.pii_input_behavior) &&
      contains(["NONE", "BLOCK", "MASK"], e.pii_output_behavior)
    ])
    error_message = "pii_input_behavior and pii_output_behavior must each be NONE, BLOCK, or MASK."
  }

  validation {
    condition     = alltrue([for e in values(var.endpoints) : e.endpoint_qpm > 0 && e.per_user_qpm > 0])
    error_message = "endpoint_qpm and per_user_qpm must be positive."
  }

  validation {
    condition     = alltrue([for e in values(var.endpoints) : e.primary_traffic_percentage >= 0 && e.primary_traffic_percentage <= 100])
    error_message = "primary_traffic_percentage must be between 0 and 100."
  }

  # Ordered fallbacks (blueprint) extend the chain, so they need a first fallback to extend.
  validation {
    condition     = alltrue([for e in values(var.endpoints) : length(e.additional_fallbacks) == 0 || e.fallback_model != ""])
    error_message = "additional_fallbacks require a first fallback (set fallback_model / fallback_provider); they extend the ordered fallback chain."
  }

  validation {
    condition = alltrue(flatten([
      for e in values(var.endpoints) : [
        for f in e.additional_fallbacks :
        contains(["openai", "azure-openai", "anthropic", "cohere", "palm", "ai21labs", "amazon-bedrock", "google-vertex-ai", "databricks-model-serving"], f.provider)
      ]
    ]))
    error_message = "each additional_fallbacks[].provider must be one of the supported providers."
  }
}
