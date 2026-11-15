# ⚡🗄️ Repair Shop — Infra Database DynamoDB (`infra-db-dynamo`)

[![CI/CD Pipeline](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-db-dynamo/actions/workflows/ci-cd-dynamo.yml/badge.svg)](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-db-dynamo/actions/workflows/ci-cd-dynamo.yml)
[![Terraform](https://img.shields.io/badge/Terraform-1.8.5-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Amazon DynamoDB](https://img.shields.io/badge/Amazon-DynamoDB-4053D6?logo=amazondynamodb&logoColor=white)](https://aws.amazon.com/dynamodb/)

Repositório de **Infraestrutura como Código (Terraform)** que provisiona as tabelas NoSQL **Amazon DynamoDB** (`tb-service_order-{env}` e `tb-payment-{env}`) da plataforma **Repair Shop (Tech Challenge FIAP — 15SOAT)**, projetadas com **Single-Table Design**, **Global Secondary Indexes (GSIs)** específicos para despacho assíncrono, criptografia em repouso (**SSE**), modo sob demanda (**`PAY_PER_REQUEST`**) e recuperação pontual (**PITR**).

---

## 📋 Índice

- [Tabelas, Chaves e GSIs Provisionados](#tabelas-chaves-e-gsis-provisionados)
- [Por que DynamoDB e NÃO um Banco Relacional neste Ponto?](#por-que-dynamodb-e-não-um-banco-relacional-neste-ponto)
- [Arquitetura Atual — Motivação e Benefícios dos Componentes](#arquitetura-atual--motivação-e-benefícios-dos-componentes)
- [Como Executar e Validar Localmente (Terraform)](#como-executar-e-validar-localmente-terraform)
- [Como Executar em Produção (Esteira CI/CD GitHub Actions)](#como-executar-em-produção-esteira-cicd-github-actions)
- [Documentação Técnica e Collection do Postman](#documentação-técnica-e-collection-do-postman)

---

## Tabelas, Chaves e GSIs Provisionados

Conforme [`infra/main.tf`](infra/main.tf) e os arquivos `infra/environments/{dev,hml,prd}.tfvars`:

| Tabela (`billing_mode = PAY_PER_REQUEST`) | Chaves Primárias | GSI (Global Secondary Index) | Consumo Principal |
| :--- | :--- | :--- | :--- |
| **`tb-service_order-${var.environment}`** | `PK` (String) / `SK` (String) | **`pending-dispatch-index`** (`payment_dispatch_status` + `update_date`) | [`app-service-order-execution-service`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service) (`ORDER#<id>` + `METADATA\|HIST#*\|EXEC#*\|EXTRA_EXEC#*`) |
| **`tb-payment-${var.environment}`** | `PK` (String) / `SK` (String) | **`dispatch-notification-index`** (`dispatch_notificate_status` + `payment_date`) | [`app-payment-service`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-payment-service) (`BILLING#<serviceOrderId>` + `PAY#*\|INV#*`) |

- **Server-Side Encryption (SSE)**: Habilitada nativamente em ambas as tabelas (`server_side_encryption { enabled = true }`).
- **Point-in-Time Recovery (PITR)**: Habilitado (`enable_point_in_time_recovery = true`) nos ambientes `dev`, `hml` e `prd`.

---

## Por que DynamoDB e NÃO um Banco Relacional neste Ponto?

A decisão de manter **PostgreSQL/RDS** apenas no cadastro mestre (`register-service`) e migrar **Ordens de Serviço** e **Pagamentos** para **Amazon DynamoDB** atende diretamente aos desafios de escala, latência e modelagem distribuída desses dois domínios:

1. **Agregados polimórficos com leitura direta sem `JOIN`s**:
   - Uma Ordem de Serviço agrupa cabeçalho (`METADATA`), histórico de até 12 transições (`HIST#*`), execuções (`EXEC#*`) e aprovações extras (`EXTRA_EXEC#*`) na mesma partição `ORDER#<id>`.
   - Um faturamento combina cobrança (`PAY#*`) e fatura/contingência (`INV#*`) sob `BILLING#<serviceOrderId>`.
   - Em um SGBD relacional, reconstituir cada agregado envolve múltiplos `JOIN`s entre tabelas normalizadas; no DynamoDB, uma única `Query` em `PK` entrega toda a árvore em milissegundos constantes.
2. **Eliminação do gargalo de conexões JDBC sob auto-scaling (HPA) e workers SQS**:
   - No Amazon EKS com HPA e *pollers* assíncronos SQS/agendadores rodando em múltiplas réplicas, abrir conexões TCP/JDBC persistentes satura rapidamente o limite de conexões de uma instância RDS (como `db.t3.micro`). O DynamoDB atende requisições via **HTTPS stateless**, escalando automaticamente por demanda (`PAY_PER_REQUEST`).
3. **Evolução contínua de schema sem bloqueios (`ALTER TABLE`)**:
   - Campos retornados por gateways externos (como Mercado Pago e metadados de contingência `PENDING_CONTINGENCY`) evoluem rapidamente. Um modelo relacional rígido demandaria migrações DDL sujeitas a *table locks*; o DynamoDB aceita novos atributos por item sem downtime.
4. **Atomicidade transacional local + consultas eficientes sem `SCAN`**:
   - Operações como gravar alteração de status + linha de histórico usam **`TransactWriteItems`** de forma atômica, enquanto varreduras periódicas de despacho (`pending-dispatch-index` e `dispatch-notification-index`) consultam diretamente os GSIs sem percorrer a tabela inteira.

---

## Arquitetura Atual — Motivação e Benefícios dos Componentes

| Pilar / Tecnologia | Papel no Ecossistema | Motivação Técnica e Pontos Positivos |
| :--- | :--- | :--- |
| **RDS (PostgreSQL 16)** | Persistência relacional do [`app-register-service`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-register-service) ([`infra-db-rds`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-db-rds)) | Preserva **ACID** e integridade referencial forte (`tb_customer`, `tb_vehicle`, `tb_user` via Flyway) onde chaves estrangeiras e restrições `UNIQUE` são vitais. |
| **DynamoDB (NoSQL)** | **Camada provisionada por este repositório** | Entrega baixa latência previsível, zero gerenciamento de instâncias/conexões, `PAY_PER_REQUEST`, PITR e suporte nativo a Single-Table Design para OS e Pagamentos. |
| **ElastiCache (Redis 7.0)** | Cache em memória ([`infra-redis`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-redis)) | Mantém cache sub-milissegundo disponível em sub-rede privada (`6379`) para suportar evolução de sessões e tokens JWT no `register-service`. |
| **Apps (EKS + Lambda Auth)** | Computação híbrida ([`infra-eks`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-eks), [`lambda-auth`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-lambda-auth)) | Combina microsserviços Kotlin/Clean Architecture em **EKS 1.31** com HPA e autenticação serverless Java 21 na borda (`lambda-auth`). |
| **Amazon SQS (Mensageria + DLQ)** | 5 filas padrão + 5 DLQs ([`infra-sqs`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-sqs)) | Orquestra a **Saga Coreografada** entre OS, Pagamento e Notificação com tolerância a falhas e isolamento em Dead Letter Queues (retenção de 14 dias). |
| **API Gateway (HTTP API v2)** | Borda única ([`infra-apigateway`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-apigateway)) | Centraliza todas as rotas públicas e o CORS (`traceparent`, `tracestate`), mantendo bancos DynamoDB e serviços EKS inacessíveis diretamente da internet. |
| **Observabilidade (Grafana)** | OpenTelemetry + Prometheus + Loki + Jaeger + Grafana | Rastreia chamadas aos SDKs DynamoDB e mensagens SQS ponta a ponta com propagação W3C, consolidando latência, erros e métricas de negócio em 11 dashboards Grafana. |

---

## Como Executar e Validar Localmente (Terraform)

> **Pré-requisitos**: **Terraform `1.8.5`**, **AWS CLI v2** autenticado (ou **LocalStack** para testes locais de criação de tabela nos arquivos `docker-compose.yml` de `app-service-order-execution-service` e `app-payment-service`).

```bash
cd infra

# Inicializar com state remoto no S3 (ex.: dev)
terraform init \
  -backend-config="bucket=SEU_BUCKET_TERRAFORM_STATE" \
  -backend-config="key=dynamodb/dev.tfstate" \
  -backend-config="region=us-east-1"

terraform fmt -check -recursive
terraform validate
terraform plan -var-file="environments/dev.tfvars"
```

---

## Como Executar em Produção (Esteira CI/CD GitHub Actions)

Pipeline definida em [`.github/workflows/ci-cd-dynamo.yml`](.github/workflows/ci-cd-dynamo.yml) e destruição controlada em [`.github/workflows/destroy.yml`](.github/workflows/destroy.yml).

### Mapeamento de Ambientes
- `develop` -> **`dev`** (`environments/dev.tfvars`)
- `homolog` -> **`hml`** (`environments/hml.tfvars`)
- `main` -> **`prd`** (`environments/prd.tfvars`)

### Etapas da Esteira
1. `terraform fmt -check` e `terraform validate`.
2. `terraform init` usando chave S3 `dynamodb/${ENV}.tfstate` no bucket `AWS_TERRAFORM_STATE_BUCKET`.
3. `terraform plan -var-file="environments/${ENV}.tfvars"`.
4. `terraform apply -auto-approve` em push para `develop`, `homolog` e `main`.

> **Posição na Ordem de Provisionamento**: Provisionado após `infra-network`, paralelamente a `infra-db-rds`, `infra-redis` e `infra-sqs`, e **antes** do deploy dos microsserviços `app-service-order-execution-service` e `app-payment-service`.

---

## Documentação Técnica e Collection do Postman

- **Arquivos Terraform deste Repositório**: [`infra/main.tf`](infra/main.tf) | [`infra/environments/dev.tfvars`](infra/environments/dev.tfvars) | [`infra/environments/hml.tfvars`](infra/environments/hml.tfvars) | [`infra/environments/prd.tfvars`](infra/environments/prd.tfvars)
- **Consumidores Diretos na Organização**:
  - [`DynamoServiceOrderRepository.kt`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/src/main/kotlin/com/cao/repairshop/serviceorder/infra/persistence/dynamo/DynamoServiceOrderRepository.kt) (`app-service-order-execution-service`)
  - [`DynamoPaymentRepository.kt`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-payment-service/blob/main/src/main/kotlin/com/cao/repairshop/payment/infrastructure/persistence/dynamo/DynamoPaymentRepository.kt) (`app-payment-service`)
- **ADRs, RFCs e Diagramas**:
  - [ADRs (`ADR-001` a `ADR-013`)](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/ADRs/README.md)
  - [RFCs (`RFC-001` a `RFC-014`)](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/RFCs/README.md)
  - [`Diagrama de Infraestrutura Cloud`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/delivery/infrastructure/repairshop-diagrama-infra-cloud.svg)
- **Postman Collections & Environments (Organização)**:
  - Collection Principal: [`Repair Shop (Tech Challenge FIAP)`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/Repair%20Shop%20%28Tech%20Challenge%20FIAP%29.postman_collection.json)
  - Collection Completa: [`Tech Challenge FIAP - Completo`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/Tech_Challenge_Fiap_-_Completo.postman_collection.json)
  - Environment Local: [`Local.postman_environment.json`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/Local.postman_environment.json)
  - Guia do Postman: [`docs/postman/README.md`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/README.md)
- **Dashboards Grafana (11 JSONs)**: [`dashboards/`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/tree/main/local/observability/grafana/dashboards)
