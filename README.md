# Unity AI Gateway — Terraform (enterprise)

Provision **N governed serving endpoints** from one config. Each endpoint fronts external models
through the Databricks AI Gateway with a consistent policy: rate limits (QPM + optional TPM), usage
tracking, inference/payload logging, PII + keyword/topic + safety guardrails, traffic routing,
automatic fallback, cost tags, an optional budget policy, and optional `CAN_QUERY` grants.

**Scale by adding an entry to `var.endpoints`** — every endpoint inherits the same governance via one
reusable module. No secrets or workspace-specific values are hardcoded.

## Structure
```
terraform/
├── versions.tf              provider + version pins (committed lock: .terraform.lock.hcl)
├── variables.tf             globals + the endpoints map (optional() defaults + validations)
├── main.tf                  provider + module "endpoint" for_each = var.endpoints
├── outputs.tf               per-endpoint id / invocation URL / log table
├── terraform.tfvars.example two sample endpoints (general + regulated)
├── backend.tf.example       remote state (S3 / azurerm / TFC) — required for teams
└── modules/ai_gateway_endpoint/   the reusable endpoint (model_serving + permissions)
```

## Prerequisites
1. **Terraform** ≥ 1.5, **Databricks provider** ≥ 1.60 (auto-installed by `init`).
2. **Workspace auth (never in code):** `export DATABRICKS_TOKEN=…` and `databricks_host`, **or** set
   `databricks_profile` to a `~/.databrickscfg` profile (`databricks auth login --host …`).
3. **Unity Catalog:** the deploying principal can create serving endpoints (+ `CAN MANAGE`), and has
   `USE CATALOG/SCHEMA` + `CREATE TABLE` on the catalog/schema used for inference logs.
4. **Provider keys in a secret scope** (values stay out of Terraform state):
   ```bash
   databricks secrets create-scope ai_gateway
   databricks secrets put-secret   ai_gateway openai_api_key
   databricks secrets put-secret   ai_gateway anthropic_api_key
   ```
5. **Remote state** for team use — copy `backend.tf.example` → `backend.tf` and configure.

## Deploy
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit for your workspace + endpoints
terraform init
terraform validate
terraform plan
terraform apply
```
Re-running `apply` reconciles to the declared state. Add/remove endpoints by editing the map.

## Feature → resource mapping
| AI Gateway capability | Where it's configured |
|---|---|
| **Many endpoints at scale** | root `main.tf` → `module "endpoint" { for_each = var.endpoints }` |
| **Rate limiting** (QPM + optional TPM, endpoint + per-user) | module `ai_gateway { rate_limits … }` via `endpoint_qpm/per_user_qpm/*_tpm` |
| **Usage tracking** | `ai_gateway { usage_tracking_config { enabled } }` → `system.ai_gateway.usage` |
| **Inference / payload logging** | `ai_gateway { inference_table_config }` → `<catalog>.<schema>.<name>_payload` (per-endpoint) |
| **PII guardrail** (block/mask, in + out) | `guardrails { input/output { pii { behavior } } }` |
| **Keyword / topic filtering** | `guardrails { input { invalid_keywords / valid_topics } }` |
| **Content safety** | `guardrails { input/output { safety } }` |
| **External models** | `config { served_entities { external_model } }` — openai, azure-openai, anthropic, cohere, palm, ai21labs, amazon-bedrock, google-vertex-ai, databricks-model-serving |
| **Provider key management** | `*_config { *_api_key = "{{secrets/<scope>/<key>}}" }` — never in state |
| **Traffic routing / load balancing** | `config { traffic_config { routes } }` — split via `primary_traffic_percentage` (100 = failover only, <100 = weighted load-balance across primary + fallback) |
| **Fallbacks** (ordered auto-failover) | `ai_gateway { fallback_config { enabled } }` — ordered chain primary → `fallback_model` → `additional_fallbacks[]`, tried in order on 429/5XX |
| **Cost attribution** | endpoint **tags** (`global_tags` + `environment` + per-endpoint) + optional `budget_policy_id` |
| **Access control** | optional `databricks_permissions` granting `CAN_QUERY` to `can_query_groups` |

## Notes
- **Single-model endpoint:** set `fallback_model = ""` — fallback entity, route, and failover are omitted.
- **Multi-field providers:** `amazon-bedrock`, `google-vertex-ai`, and `azure-openai` read extra settings from
  `primary_provider_config` / `fallback_provider_config` (region, project, deployment, IAM role, …). Bedrock
  supports role-based auth (`instance_profile_arn`) or static keys; sensitive values are always secret references.
- **Even more providers:** add a matching `dynamic "<provider>_config"` in `modules/ai_gateway_endpoint/main.tf`
  and extend the provider validation in `variables.tf`.
- **State hygiene:** provider keys are secret references (never in state), but still treat state as
  sensitive and use the remote backend for any shared use.

---

## Notice
Provided by **Databricks Field Engineering** for demonstration and enablement — **not an official
Databricks product**, offered **as-is without warranty**. Example data is **synthetic**; no secrets are
included (provider keys are secret references, never in state). Databricks features evolve — validate
against your workspace's current provider/API versions before production use. See `NOTICE.md`.
