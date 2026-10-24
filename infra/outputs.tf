output "service_order_table_name" {
  description = "Nome da tabela de Ordens de Serviço"
  value       = aws_dynamodb_table.service_order.name
}

output "service_order_table_arn" {
  description = "ARN da tabela de Ordens de Serviço"
  value       = aws_dynamodb_table.service_order.arn
}

output "payment_table_name" {
  description = "Nome da tabela de Pagamentos"
  value       = aws_dynamodb_table.payment.name
}

output "payment_table_arn" {
  description = "ARN da tabela de Pagamentos"
  value       = aws_dynamodb_table.payment.arn
}
