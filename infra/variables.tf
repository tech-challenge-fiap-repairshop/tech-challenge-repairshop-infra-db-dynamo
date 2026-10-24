variable "aws_region" {
  description = "Região da AWS para provisionamento"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de execução (dev, hml, prd)"
  type        = string
  default     = "dev"
}

variable "billing_mode" {
  description = "Modo de cobrança do DynamoDB (PAY_PER_REQUEST ou PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "enable_point_in_time_recovery" {
  description = "Habilitar PITR para backups contínuos"
  type        = bool
  default     = true
}
