# Module: one governed AI Gateway serving endpoint fronting external model(s).
# All values are passed in by the root module; nothing is hardcoded here.

variable "endpoint_name" {
  type        = string
  description = "Serving endpoint name (unique per workspace)."
}

variable "description" {
  type        = string
  description = "Human-readable endpoint description."
  default     = "Governed AI Gateway endpoint"
}

# --- Unity Catalog targets for inference logging ---
variable "catalog" {
  type        = string
  description = "UC catalog for the inference (payload) log table."
}

variable "schema" {
  type        = string
  description = "UC schema for the inference log table."
}

variable "inference_table_prefix" {
  type        = string
  description = "Inference table name prefix (table = <catalog>.<schema>.<prefix>_payload)."
}

# --- Provider keys (secret references, never values) ---
variable "secret_scope" {
  type        = string
  description = "Databricks secret scope holding the provider API keys."
}

variable "primary_provider" {
  type        = string
  description = "Primary provider: openai | azure-openai | anthropic | cohere | palm | ai21labs | amazon-bedrock | google-vertex-ai | databricks-model-serving."
}

variable "primary_model" {
  type        = string
  description = "Primary external model name."
}

variable "primary_key_name" {
  type        = string
  description = "Secret key (in secret_scope) for the primary provider."
}

variable "fallback_provider" {
  type        = string
  description = "Fallback provider (same set as primary_provider). Ignored when fallback_model is empty."
}

variable "fallback_model" {
  type        = string
  description = "Fallback external model name. Empty = single-model endpoint (no failover)."
}

variable "fallback_key_name" {
  type        = string
  description = "Secret key (in secret_scope) for the fallback provider."
}

variable "primary_traffic_percentage" {
  type        = number
  description = "Steady-state traffic percentage (0-100) sent to the primary entity; the remainder goes to the fallback entity when one is set. 100 = active/passive failover only; <100 = load-balance across primary + fallback. Ignored when there is no fallback."
  default     = 100

  validation {
    condition     = var.primary_traffic_percentage >= 0 && var.primary_traffic_percentage <= 100
    error_message = "primary_traffic_percentage must be between 0 and 100."
  }
}

# --- Multi-field provider config (only used by the provider that needs it) ---
# Simple key-only providers (openai, anthropic, cohere, palm, ai21labs) ignore this.
variable "primary_provider_config" {
  type = object({
    # amazon-bedrock: region + which upstream, then role-based (instance_profile_arn)
    # OR key-based (aws_access_key_name secret + the entity key as the secret access key).
    aws_region           = optional(string, "")
    bedrock_provider     = optional(string, "") # anthropic | cohere | ai21labs | amazon
    aws_access_key_name  = optional(string, "") # secret name in secret_scope; "" = role-based
    instance_profile_arn = optional(string, "") # role-based auth (no static keys)
    # google-vertex-ai
    vertex_project_id = optional(string, "")
    vertex_region     = optional(string, "")
    # azure-openai (external_model provider stays "openai", api_type = "azure")
    openai_api_base        = optional(string, "")
    openai_deployment_name = optional(string, "")
    openai_api_version     = optional(string, "")
  })
  description = "Provider-specific config for the primary entity (Bedrock / Vertex / Azure OpenAI). All optional; unused fields ignored."
  default     = {}
}

variable "fallback_provider_config" {
  type = object({
    aws_region             = optional(string, "")
    bedrock_provider       = optional(string, "")
    aws_access_key_name    = optional(string, "")
    instance_profile_arn   = optional(string, "")
    vertex_project_id      = optional(string, "")
    vertex_region          = optional(string, "")
    openai_api_base        = optional(string, "")
    openai_deployment_name = optional(string, "")
    openai_api_version     = optional(string, "")
  })
  description = "Provider-specific config for the fallback entity (same shape as primary_provider_config)."
  default     = {}
}

variable "additional_fallbacks" {
  type = list(object({
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
  }))
  description = "Ordered additional fallback entities beyond the first fallback (blueprint: 'ordered fallbacks for 429/5XX'). Tried in list order on error, after primary + first fallback. Requires a first fallback. [] = none."
  default     = []
}

# --- Rate limits ---
variable "endpoint_qpm" {
  type        = number
  description = "Endpoint-wide queries/minute."
}

variable "per_user_qpm" {
  type        = number
  description = "Per-user queries/minute."
}

variable "endpoint_tpm" {
  type        = number
  description = "Endpoint-wide tokens/minute (0 disables the token limit)."
  default     = 0
}

variable "per_user_tpm" {
  type        = number
  description = "Per-user tokens/minute (0 disables)."
  default     = 0
}

# --- Observability ---
variable "enable_payload_logging" {
  type        = bool
  description = "Enable the per-endpoint inference/payload log table (full request/response). Best practice: enable only where auditing/debugging is justified, with retention controls. Usage-metric tracking stays on regardless."
  default     = true
}

# --- Guardrails ---
variable "enable_safety" {
  type        = bool
  description = "Enable content-safety guardrail on input + output."
}

variable "pii_input_behavior" {
  type        = string
  description = "PII behaviour on input: NONE | BLOCK | MASK."
}

variable "pii_output_behavior" {
  type        = string
  description = "PII behaviour on output: NONE | BLOCK | MASK."
}

variable "blocked_keywords" {
  type        = list(string)
  description = "Keywords blocked on input ([] disables)."
}

variable "allowed_topics" {
  type        = list(string)
  description = "Allow-listed topics ([] disables)."
}

# --- Access control + cost governance ---
variable "can_query_groups" {
  type        = list(string)
  description = "Account groups granted CAN_QUERY ([] leaves default permissions)."
}

variable "budget_policy_id" {
  type        = string
  description = "Optional Unity Catalog budget policy id to attribute usage to (\"\" = none)."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Resource tags (cost center, owner, environment, …)."
  default     = {}
}

variable "notification_emails" {
  type        = list(string)
  description = "Emails alerted on endpoint update failure (ops). [] disables notifications."
  default     = []
}

variable "databricks_workspace_url" {
  type        = string
  description = "Workspace URL used only by the 'databricks-model-serving' provider (proxying a Databricks-hosted model). Ignored for external SaaS providers."
  default     = ""
}
