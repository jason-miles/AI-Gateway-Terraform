# Module: `ai_gateway_endpoint`

Provisions **one** governed AI Gateway serving endpoint (`databricks_model_serving`) that fronts one or
two external models, with the full gateway policy applied, plus optional `CAN_QUERY` grants.

## Usage
```hcl
module "endpoint" {
  source = "../../modules/ai_gateway_endpoint"

  endpoint_name          = "ai-gateway-general"
  catalog                = "main"
  schema                 = "ai_gateway"
  inference_table_prefix = "ai_gateway_general"
  secret_scope           = "ai_gateway"

  primary_provider = "openai"
  primary_model    = "gpt-4o"
  primary_key_name = "openai_api_key"

  fallback_provider = "anthropic"
  fallback_model    = "claude-3-5-sonnet-20241022"
  fallback_key_name = "anthropic_api_key"

  endpoint_qpm = 1000
  per_user_qpm = 60
  per_user_tpm = 200000

  enable_safety       = true
  pii_input_behavior  = "BLOCK"
  pii_output_behavior = "MASK"
  blocked_keywords    = []
  allowed_topics      = []

  can_query_groups = ["ai-platform-users"]
  budget_policy_id = ""
  tags             = { environment = "prod", cost_center = "ai-platform" }
}
```

## Inputs (highlights)
| Name | Type | Default | Notes |
|---|---|---|---|
| `endpoint_name` | string | — | Unique per workspace. |
| `catalog` / `schema` / `inference_table_prefix` | string | — | UC target for the inference log table `<catalog>.<schema>.<prefix>_payload`. |
| `secret_scope` | string | — | Holds provider keys; referenced as `{{secrets/<scope>/<key>}}`. |
| `primary_provider` / `fallback_provider` | string | — | One of `openai`, `anthropic`, `cohere`, `palm`, `ai21labs`. |
| `*_model` / `*_key_name` | string | — | Model id + secret key. `fallback_model=""` → single-model, no failover. |
| `endpoint_qpm` / `per_user_qpm` | number | — | Rate limits (queries/min). |
| `endpoint_tpm` / `per_user_tpm` | number | 0 | Token/min limits (0 disables). |
| `enable_safety` | bool | — | Content-safety guardrail. |
| `pii_input_behavior` / `pii_output_behavior` | string | — | `NONE` \| `BLOCK` \| `MASK`. |
| `blocked_keywords` / `allowed_topics` | list(string) | — | Keyword/topic filters (empty disables). |
| `can_query_groups` | list(string) | — | Groups granted `CAN_QUERY` (empty = default perms). |
| `budget_policy_id` | string | `""` | Optional UC budget policy. |
| `tags` | map(string) | `{}` | Cost/ownership tags. |

## Outputs
| Name | Description |
|---|---|
| `name` | Endpoint name |
| `id` | `serving_endpoint_id` |
| `inference_log_table` | `<catalog>.<schema>.<prefix>_payload` |

## Extending providers
Single-API-key providers (`openai`, `anthropic`, `cohere`, `palm`, `ai21labs`) are wired via the
`dynamic "<provider>_config"` blocks inside `served_entities.external_model`. To add a **multi-field**
provider, add a matching dynamic block and pass the extra secret references. Examples of the exact
attribute names (from the provider schema):

```hcl
# Amazon Bedrock
dynamic "amazon_bedrock_config" {
  for_each = served_entities.value.provider == "amazon-bedrock" ? [1] : []
  content {
    aws_region            = var.aws_region
    aws_access_key_id     = "{{secrets/${var.secret_scope}/aws_access_key_id}}"
    aws_secret_access_key = "{{secrets/${var.secret_scope}/aws_secret_access_key}}"
    bedrock_provider      = "anthropic"
  }
}

# Google Cloud Vertex AI
dynamic "google_cloud_vertex_ai_config" {
  for_each = served_entities.value.provider == "google-cloud-vertex-ai" ? [1] : []
  content {
    project_id  = var.gcp_project_id
    region      = var.gcp_region
    private_key = "{{secrets/${var.secret_scope}/gcp_private_key}}"
  }
}

# Databricks-hosted foundation model as a served entity
dynamic "databricks_model_serving_config" {
  for_each = served_entities.value.provider == "databricks" ? [1] : []
  content {
    databricks_workspace_url = var.databricks_host
    databricks_api_token     = "{{secrets/${var.secret_scope}/databricks_token}}"
  }
}
```
Then widen the provider validation in the root `variables.tf`.
