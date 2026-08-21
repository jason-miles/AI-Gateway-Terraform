# Terratest suite

Automated tests for the AI Gateway Terraform, using [Terratest](https://terratest.gruntwork.io/).

## Layout
| File | What it does | Needs a workspace? |
|---|---|---|
| `validate_test.go` | `init` + `validate` the root config and all three examples | **No** — runs in CI |
| `integration_test.go` | `apply` a throwaway endpoint, assert it converges, then `destroy` | **Yes** — gated by `RUN_TF_INTEGRATION` |

## Prerequisites
- Go ≥ 1.21, Terraform ≥ 1.5 on PATH.
- First run: `go mod tidy` (populates `go.sum` + indirect deps).

## Run the validation tests (no credentials)
```bash
cd terraform/test
go mod tidy
go test -run Validate -v
```

## Run the integration test (real apply + destroy)
Uses the in-plane `databricks-model-serving` provider, so it needs **no third-party key** — just a
workspace PAT stored in a secret scope under key `databricks_token`:
```bash
# one-time: create the scope + PAT secret
databricks secrets create-scope aigw_tf_apply
databricks tokens create --comment terratest --lifetime-seconds 3600 -o json \
  | jq -r .token_value | databricks secrets put-secret aigw_tf_apply databricks_token

export RUN_TF_INTEGRATION=1
export DATABRICKS_HOST="https://<workspace>.cloud.databricks.com"   # + DATABRICKS_TOKEN or a profile
export TF_CATALOG="main" TF_SCHEMA="ai_gateway" TF_VAR_secret_scope="aigw_tf_apply"

cd terraform/test && go test -run Integration -v -timeout 30m
```
The test always runs `terraform destroy` on cleanup (even if an assertion fails). Revoke the PAT and
delete the scope afterwards.

> This makes the apply→verify→destroy flow repeatable in CI (behind the gate, with credentials
> supplied as secrets), rather than a one-off manual run.
