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
  description = "Primary external model provider (openai | anthropic)."
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
  description = "Fallback provider (openai | anthropic). Ignored when fallback_model is empty."
}

variable "fallback_model" {
  type        = string
  description = "Fallback external model name. Empty = single-model endpoint (no failover)."
}

variable "fallback_key_name" {
  type        = string
  description = "Secret key (in secret_scope) for the fallback provider."
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
