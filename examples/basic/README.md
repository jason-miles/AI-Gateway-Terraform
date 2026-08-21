# Example · basic

The smallest useful config: one governed endpoint, one provider (OpenAI), no fallback, PII
block-in / mask-out, per-user rate limit.

```bash
cd terraform/examples/basic
export DATABRICKS_TOKEN=...            # or use a CLI profile
terraform init
terraform validate
terraform apply -var databricks_host="https://your-workspace.cloud.databricks.com"
```
Prereq: a `main.ai_gateway` schema you can write to, and secret `ai_gateway/openai_api_key`.
