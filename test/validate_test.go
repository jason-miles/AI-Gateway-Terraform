package test

// Validation tests — no workspace credentials required. These run in CI and locally:
//   cd terraform/test && go mod tidy && go test -run Validate -v
//
// They prove the root config and every example initialise and validate cleanly.

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// TestValidateRoot validates the root module.
func TestValidateRoot(t *testing.T) {
	t.Parallel()
	terraform.InitAndValidate(t, &terraform.Options{
		TerraformDir: "..",
		NoColor:      true,
	})
}

// TestValidateExamples validates each shipped example.
func TestValidateExamples(t *testing.T) {
	examples := []string{"basic", "multi-provider-fallback", "multi-region"}
	for _, ex := range examples {
		ex := ex // capture
		t.Run(ex, func(t *testing.T) {
			t.Parallel()
			terraform.InitAndValidate(t, &terraform.Options{
				TerraformDir: filepath.Join("..", "examples", ex),
				NoColor:      true,
			})
		})
	}
}
