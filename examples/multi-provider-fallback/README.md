# Example · multi-provider + fallback

OpenAI primary with a **Cohere** fallback (shows provider support beyond OpenAI/Anthropic),
a per-user token/min cap, a blocked keyword, and a `CAN_QUERY` grant to a group.

```bash
cd terraform/examples/multi-provider-fallback
terraform init && terraform validate
terraform apply -var databricks_host="https://your-workspace.cloud.databricks.com"
```
Prereq secrets: `ai_gateway/openai_api_key`, `ai_gateway/cohere_api_key`. Group `ai-platform-users` must exist.
