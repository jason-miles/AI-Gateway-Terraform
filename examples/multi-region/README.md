# Example · multi-region (data residency)

One identical governed endpoint per region via **aliased providers** — the pattern for POPIA/GDPR
data-residency, where prompts/responses for a region must stay in that region's workspace.

```bash
cd terraform/examples/multi-region
terraform init && terraform validate
terraform apply \
  -var region_a_host="https://ws-af-south-1.cloud.databricks.com" \
  -var region_b_host="https://ws-eu-west-1.cloud.databricks.com"
```
Each region authenticates independently (per-profile or per-`DATABRICKS_CONFIG_PROFILE`). See
`../../NETWORKING.md` for the residency + PrivateLink considerations behind this pattern.
