output "endpoints" {
  description = "Per-endpoint details: id, invocation URL, and inference log table."
  value = {
    for name, m in module.endpoint : name => {
      id                  = m.id
      invocation_url      = "${var.databricks_host}/serving-endpoints/${name}/invocations"
      inference_log_table = m.inference_log_table
    }
  }
}

output "usage_system_table" {
  description = "System table for token/cost/latency usage and per-user attribution (all endpoints)."
  value       = "system.ai_gateway.usage"
}
