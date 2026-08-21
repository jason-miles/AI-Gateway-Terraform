package test

// Integration test — provisions a real throwaway endpoint, asserts it converges,
// then destroys it. Gated behind RUN_TF_INTEGRATION so it never runs by accident.
//
// Prereqs to run:
//   export RUN_TF_INTEGRATION=1
//   export DATABRICKS_HOST=https://<workspace>        # + auth: DATABRICKS_TOKEN or a CLI profile
//   export TF_VAR_secret_scope=<scope with a Databricks PAT under key `databricks_token`>
//   (optional) TF_CATALOG, TF_SCHEMA, TF_TARGET_MODEL
//   cd terraform/test && go mod tidy && go test -run Integration -v -timeout 30m
//
// It uses the in-plane `databricks-model-serving` provider (no third-party key): the endpoint
// proxies an existing Databricks-hosted model, authenticated with a workspace PAT from the scope.

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func TestIntegrationApplyDestroy(t *testing.T) {
	if os.Getenv("RUN_TF_INTEGRATION") == "" {
		t.Skip("set RUN_TF_INTEGRATION=1 (plus DATABRICKS auth + a secret scope) to run this")
	}

	host := os.Getenv("DATABRICKS_HOST")
	require.NotEmpty(t, host, "DATABRICKS_HOST must be set")
	scope := getenv("TF_VAR_secret_scope", "aigw_tf_apply")

	opts := &terraform.Options{
		TerraformDir: "..",
		NoColor:      true,
		Vars: map[string]interface{}{
			"databricks_host": host,
			"catalog":         getenv("TF_CATALOG", "main"),
			"schema":          getenv("TF_SCHEMA", "ai_gateway"),
			"secret_scope":    scope,
			"environment":     "terratest",
			"endpoints": map[string]interface{}{
				"aigw-terratest": map[string]interface{}{
					"description":      "Terratest throwaway endpoint",
					"primary_provider": "databricks-model-serving",
					"primary_model":    getenv("TF_TARGET_MODEL", "databricks-claude-haiku-4-5"),
					"primary_key_name": "databricks_token",
					"fallback_model":   "",
					"endpoint_qpm":     60,
					"per_user_qpm":     20,
					"tags":             map[string]interface{}{"lifecycle": "terratest"},
				},
			},
		},
	}

	// Always clean up, even on assertion failure.
	defer terraform.Destroy(t, opts)

	terraform.InitAndApply(t, opts)

	// The gateway usage table is a stable, known output — a cheap convergence assertion.
	assert.Equal(t, "system.ai_gateway.usage", terraform.Output(t, opts, "usage_system_table"))

	// The endpoints output must contain our endpoint with a non-empty id.
	endpoints := terraform.OutputMapOfObjects(t, opts, "endpoints")
	require.Contains(t, endpoints, "aigw-terratest")
	ep := endpoints["aigw-terratest"].(map[string]interface{})
	assert.NotEmpty(t, ep["id"], "endpoint id should be known after apply")
	assert.Contains(t, ep["inference_log_table"].(string), "aigw_terratest_payload")
}
