# ⚡ Tech Challenge RepairShop - Infra DB Dynamo (AWS DynamoDB NoSQL)

> **Repositório de Infraestrutura como Código (Terraform) para Banco NoSQL DynamoDB**  
> **Tech Challenge SOAT (Fase 4)**  
> **Organização GitHub:** `tech-challenge-fiap-repairshop`

---

## 📌 Visão Geral

O repositório **`tech-challenge-repairshop-infra-db-dynamo`** centraliza o provisionamento e governança de infraestrutura em nuvem via **Terraform** para as tabelas NoSQL de alta performance no **AWS DynamoDB**.

Ele atende aos microsserviços de Ordem de Serviço (`service_order_execution-service`) e Pagamentos (`payment-service`), viabilizando o modelo de persistência poliglota (*Database per Service*).

---

## 🏛️ Tabelas Provisionadas

| Tabela | Microsserviço Proprietário | Padrão de Modelagem | Índices Secundários Globais (GSIs) |
| :--- | :--- | :--- | :--- |
| **`tb-service_order`** | `service_order_execution-service` | **Single-Table Design** (`order_metadata`, `order_history`, `execution`, `insume`) | `pending-dispatch-index` (GSI-PK: `payment_dispatch_status`, GSI-SK: `update_date`) |
| **`tb-payment`** | `payment-service` | Registro transacional e faturamento (`item_payment`, `item_invoice`) | `dispatch-notification-index` (GSI-PK: `dispatch_notificate_status`, GSI-SK: `payment_date`) |

- **Billing Mode:** `PAY_PER_REQUEST` (On-Demand).
- **Recuperação de Desastres:** Point-in-Time Recovery (PITR) ativado para restauração contínua.
- **Segurança:** Server-Side Encryption (KMS AWS Managed).

---

## 📂 Estrutura de Diretórios

```
tech-challenge-repairshop-infra-db-dynamo/
├── .github/workflows/         # Pipeline Terraform Plan & Apply (GitHub Actions)
├── infra/
│   ├── environments/          # dev.tfvars, hml.tfvars, prd.tfvars
│   ├── backend.tf             # Remote state S3 (bucket: fiap-repairshop2)
│   ├── main.tf                # Tabelas tb-service_order e tb-payment + GSIs
│   ├── outputs.tf             # Nomes e ARNs das tabelas DynamoDB
│   ├── providers.tf           # Configuração do AWS Provider
│   ├── variables.tf           # Parametrização por ambiente e modo de cobrança
│   └── versions.tf            # Versões mínimas requeridas
├── .gitignore
└── README.md
```

---

## 🚀 Como Aplicar Localmente

```bash
cd infra

# Inicializar Terraform
terraform init

# Validar configurações
terraform validate

# Planejar (dev)
terraform plan -var-file="environments/dev.tfvars"

# Aplicar (dev)
terraform apply -var-file="environments/dev.tfvars"
```

---

## 🛡️ Governança de Branches
- `main`: Branch de produção (protegida contra push direto).
- `homolog`: Branch de homologação.
- `develop`: Branch de desenvolvimento ativo.
- `feat/*`, `fix/*`, `chore/*`: Branches de trabalho.
