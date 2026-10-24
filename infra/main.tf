# -----------------------------------------------------------------------------
# Table: tb-service_order (Single-Table Design)
# Usada por: service_order_execution-service
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "service_order" {
  name         = "tb-service_order-${var.environment}"
  billing_mode = var.billing_mode
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "payment_dispatch_status"
    type = "S"
  }

  attribute {
    name = "update_date"
    type = "S"
  }

  global_secondary_index {
    name            = "pending-dispatch-index"
    hash_key        = "payment_dispatch_status"
    range_key       = "update_date"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "tb-service_order-${var.environment}"
    Service     = "service_order_execution-service"
    DesignModel = "Single-Table-Design"
  }
}

# -----------------------------------------------------------------------------
# Table: tb-payment
# Usada por: payment-service
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "payment" {
  name         = "tb-payment-${var.environment}"
  billing_mode = var.billing_mode
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "dispatch_notificate_status"
    type = "S"
  }

  attribute {
    name = "payment_date"
    type = "S"
  }

  global_secondary_index {
    name            = "dispatch-notification-index"
    hash_key        = "dispatch_notificate_status"
    range_key       = "payment_date"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name    = "tb-payment-${var.environment}"
    Service = "payment-service"
  }
}
