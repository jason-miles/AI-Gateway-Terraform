config {
  # Lint modules and examples too.
  call_module_type = "all"
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Naming + hygiene rules (from the built-in terraform ruleset).
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}
