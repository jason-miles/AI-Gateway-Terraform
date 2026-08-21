# Example: a single governed endpoint, one provider, no fallback.
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.60.0, < 2.0.0"
    }
  }
}

variable "databricks_host" {
  type        = string
  description = "Workspace URL. Auth via env/CLI."
}

provider "databricks" {
  host = var.databricks_host
}

module "endpoint" {
  source = "../../modules/ai_gateway_endpoint"

  endpoint_name          = "ai-gateway-basic"
  description            = "Single-model governed endpoint (example)"
  catalog                = "main"
  schema                 = "ai_gateway"
  inference_table_prefix = "ai_gateway_basic"
  secret_scope           = "ai_gateway"

  primary_provider = "openai"
  primary_model    = "gpt-4o"
  primary_key_name = "openai_api_key"

  # No fallback in this example.
  fallback_provider = "anthropic"
  fallback_model    = ""
  fallback_key_name = "anthropic_api_key"

  endpoint_qpm = 300
  per_user_qpm = 30

  enable_safety       = true
  pii_input_behavior  = "BLOCK"
  pii_output_behavior = "MASK"
  blocked_keywords    = []
  allowed_topics      = []

  can_query_groups = []
  tags             = { environment = "dev", example = "basic" }
}

output "endpoint" {
  value = {
    id                  = module.endpoint.id
    inference_log_table = module.endpoint.inference_log_table
  }
}
