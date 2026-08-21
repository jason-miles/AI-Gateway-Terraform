output "name" {
  description = "Endpoint name."
  value       = databricks_model_serving.this.name
}

output "id" {
  description = "Serving endpoint resource id."
  value       = databricks_model_serving.this.serving_endpoint_id
}

output "inference_log_table" {
  description = "UC table with full request/response payloads."
  value       = "${var.catalog}.${var.schema}.${var.inference_table_prefix}_payload"
}
