# Example: one governed endpoint per region, using aliased providers.
# Pattern for data residency (e.g. POPIA/GDPR): deploy an identical governed
# endpoint into a workspace in each region; route apps to their in-region URL.
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.60.0, < 2.0.0"
    }
  }
}

variable "region_a_host" {
  type        = string
  description = "Workspace URL for region A (e.g. af-south-1)."
}

variable "region_b_host" {
  type        = string
  description = "Workspace URL for region B (e.g. eu-west-1)."
}

provider "databricks" {
  alias = "region_a"
  host  = var.region_a_host
}

provider "databricks" {
  alias = "region_b"
  host  = var.region_b_host
}

locals {
  # Identical governance in both regions — one definition, applied per region.
  common = {
    catalog             = "main"
    schema              = "ai_gateway"
    secret_scope        = "ai_gateway"
    primary_provider    = "openai"
    primary_model       = "gpt-4o"
    primary_key_name    = "openai_api_key"
    fallback_provider   = "anthropic"
    fallback_model      = "claude-3-5-sonnet-20241022"
    fallback_key_name   = "anthropic_api_key"
    endpoint_qpm        = 500
    per_user_qpm        = 50
    enable_safety       = true
    pii_input_behavior  = "BLOCK"
    pii_output_behavior = "MASK"
    blocked_keywords    = []
    allowed_topics      = []
    can_query_groups    = []
  }
}

module "region_a" {
  source                 = "../../modules/ai_gateway_endpoint"
  providers              = { databricks = databricks.region_a }
  endpoint_name          = "ai-gateway-region-a"
  description            = "Governed endpoint — region A"
  inference_table_prefix = "ai_gateway_region_a"
  tags                   = { region = "a", environment = "prod" }

  catalog             = local.common.catalog
  schema              = local.common.schema
  secret_scope        = local.common.secret_scope
  primary_provider    = local.common.primary_provider
  primary_model       = local.common.primary_model
  primary_key_name    = local.common.primary_key_name
  fallback_provider   = local.common.fallback_provider
  fallback_model      = local.common.fallback_model
  fallback_key_name   = local.common.fallback_key_name
  endpoint_qpm        = local.common.endpoint_qpm
  per_user_qpm        = local.common.per_user_qpm
  enable_safety       = local.common.enable_safety
  pii_input_behavior  = local.common.pii_input_behavior
  pii_output_behavior = local.common.pii_output_behavior
  blocked_keywords    = local.common.blocked_keywords
  allowed_topics      = local.common.allowed_topics
  can_query_groups    = local.common.can_query_groups
}

module "region_b" {
  source                 = "../../modules/ai_gateway_endpoint"
  providers              = { databricks = databricks.region_b }
  endpoint_name          = "ai-gateway-region-b"
  description            = "Governed endpoint — region B"
  inference_table_prefix = "ai_gateway_region_b"
  tags                   = { region = "b", environment = "prod" }

  catalog             = local.common.catalog
  schema              = local.common.schema
  secret_scope        = local.common.secret_scope
  primary_provider    = local.common.primary_provider
  primary_model       = local.common.primary_model
  primary_key_name    = local.common.primary_key_name
  fallback_provider   = local.common.fallback_provider
  fallback_model      = local.common.fallback_model
  fallback_key_name   = local.common.fallback_key_name
  endpoint_qpm        = local.common.endpoint_qpm
  per_user_qpm        = local.common.per_user_qpm
  enable_safety       = local.common.enable_safety
  pii_input_behavior  = local.common.pii_input_behavior
  pii_output_behavior = local.common.pii_output_behavior
  blocked_keywords    = local.common.blocked_keywords
  allowed_topics      = local.common.allowed_topics
  can_query_groups    = local.common.can_query_groups
}

output "region_a_table" {
  value = module.region_a.inference_log_table
}

output "region_b_table" {
  value = module.region_b.inference_log_table
}
