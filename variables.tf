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
    description         = optional(string, "Governed AI Gateway endpoint")
    primary_provider    = optional(string, "openai")
    primary_model       = optional(string, "gpt-4o")
    primary_key_name    = optional(string, "openai_api_key")
    fallback_provider   = optional(string, "anthropic")
    fallback_model      = optional(string, "")
    fallback_key_name   = optional(string, "anthropic_api_key")
    endpoint_qpm        = optional(number, 500)
    per_user_qpm        = optional(number, 50)
    endpoint_tpm        = optional(number, 0)
    per_user_tpm        = optional(number, 0)
    enable_safety       = optional(bool, true)
    pii_input_behavior  = optional(string, "BLOCK")
    pii_output_behavior = optional(string, "MASK")
    blocked_keywords    = optional(list(string), [])
    allowed_topics      = optional(list(string), [])
    can_query_groups    = optional(list(string), [])
    budget_policy_id    = optional(string, "")
    tags                = optional(map(string), {})
    notification_emails = optional(list(string), [])
  }))

  validation {
    condition = alltrue([
      for e in values(var.endpoints) :
      contains(["openai", "anthropic", "cohere", "palm", "ai21labs", "databricks-model-serving"], e.primary_provider) &&
      (e.fallback_model == "" || contains(["openai", "anthropic", "cohere", "palm", "ai21labs", "databricks-model-serving"], e.fallback_provider))
    ])
    error_message = "primary_provider / fallback_provider must be one of: openai, anthropic, cohere, palm, ai21labs, databricks-model-serving. (Other multi-field providers — amazon_bedrock, google_cloud_vertex_ai — need a small module extension; see modules/ai_gateway_endpoint/README.md.)"
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
}
