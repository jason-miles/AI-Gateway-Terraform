# Example: OpenAI primary with a Cohere fallback (beyond openai/anthropic),
# per-user token limit, a keyword filter, and a CAN_QUERY grant.
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
  type = string
}

provider "databricks" {
  host = var.databricks_host
}

module "endpoint" {
  source = "../../modules/ai_gateway_endpoint"

  endpoint_name          = "ai-gateway-multi"
  description            = "OpenAI primary + Cohere fallback (example)"
  catalog                = "main"
  schema                 = "ai_gateway"
  inference_table_prefix = "ai_gateway_multi"
  secret_scope           = "ai_gateway"

  primary_provider = "openai"
  primary_model    = "gpt-4o"
  primary_key_name = "openai_api_key"

  fallback_provider = "cohere"
  fallback_model    = "command-r-plus"
  fallback_key_name = "cohere_api_key"

  endpoint_qpm = 800
  per_user_qpm = 60
  per_user_tpm = 300000

  enable_safety       = true
  pii_input_behavior  = "MASK"
  pii_output_behavior = "MASK"
  blocked_keywords    = ["internal-codename"]
  allowed_topics      = []

  can_query_groups = ["ai-platform-users"]
  tags             = { environment = "prod", example = "multi-provider" }
}

output "endpoint" {
  value = {
    id                  = module.endpoint.id
    inference_log_table = module.endpoint.inference_log_table
  }
}
