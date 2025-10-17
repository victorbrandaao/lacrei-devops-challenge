# Lacrei Saúde - DevOps Challenge

Pipeline de deploy seguro e escalável para aplicações containerizadas na AWS, seguindo as melhores práticas de infraestrutura como código, CI/CD e segurança.

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Actions                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐ │
│  │   Test   │ -> │  Build   │ -> │ Staging  │ -> │   Prod   │ │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘ │
└────────────┬────────────────────────────────────────────────────┘
             │
             v
┌────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                             │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  VPC (10.20.0.0/16)                                      │ │
│  │  ├─ Public Subnet A (AZ-1)                               │ │
│  │  └─ Public Subnet B (AZ-2)                               │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────┐      ┌─────────────┐      ┌──────────────────────┐  │
│  │ ALB  │ ---> │ Target Group│ ---> │  ECS Service (EC2)   │  │
│  │ HTTP │      │ /status     │      │  ├─ Task Definition  │  │
│  │HTTPS │      │ Health: 30s │      │  └─ Container (3000) │  │
│  └──────┘      └─────────────┘      └──────────────────────┘  │
│                                                                 │
│  ┌─────────┐   ┌──────────────┐    ┌──────────────────────┐   │
│  │   ECR   │   │  CloudWatch  │    │   Security Groups    │   │
│  │  Scan   │   │     Logs     │    │  Least Privilege     │   │
│  └─────────┘   └──────────────┘    └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Tecnologias Utilizadas

- **Containerização**: Docker (multi-stage build, non-root user)
- **Infraestrutura**: Terraform (AWS VPC, ECS, ALB, ECR, CloudWatch)
- **CI/CD**: GitHub Actions (test, build, deploy staging/prod)
- **Cloud Provider**: AWS (EC2, ECS, ALB, CloudWatch, ACM)
- **Linguagem**: Node.js 18 (Alpine Linux)
- **Testes**: Jest (100% coverage)

## 📋 Estrutura do Projeto

```
lacrei-devops-challenge/
├── .github/
│   └── workflows/
│       └── ci.yml              # Pipeline CI/CD completo
├── src/
│   ├── app.js                  # Express app
│   ├── server.js               # HTTP server
│   ├── routes/
│   │   └── status.js           # Endpoint /status
│   └── __tests__/
│       └── status.test.js      # Testes unitários
├── lacrei-infra/
│   ├── main.tf                 # Infraestrutura AWS
│   ├── variables.tf            # Variáveis Terraform
│   └── outputs.tf              # Outputs (ALB DNS, ECR URL)
├── Dockerfile                  # Container otimizado
├── .dockerignore
├── package.json
└── jest.config.js
```

## 🔐 Segurança Implementada

### ✅ Checklist de Segurança

- [x] **Secrets Management**: GitHub Secrets (AWS credentials nunca no código)
- [x] **Container Security**:
  - Usuário não-root (nodejs:1001)
  - Multi-stage build (reduz superfície de ataque)
  - Image scan automático no ECR
  - Alpine Linux (imagem minimal)
- [x] **Network Security**:
  - Security Groups com menor privilégio
  - ALB como único ponto de entrada
  - Containers acessíveis apenas via ALB
- [x] **HTTPS/TLS**:
  - Certificado ACM com validação DNS
  - Redirect HTTP -> HTTPS (301)
  - SSL Policy: ELBSecurityPolicy-2016-08
- [x] **IAM Roles**:
  - ECS Instance Role (mínimo necessário)
  - Task Execution Role (pull ECR + logs)
- [x] **Immutable Infrastructure**:
  - ECR tags immutable
  - Task definitions versionadas

## 🔄 Pipeline CI/CD

### Fluxo Completo

1. **Test** (PR + Push)

   - Checkout código
   - Setup Node.js 18
   - Instalar dependências
   - Executar testes (Jest + coverage)
   - Upload coverage para Codecov

2. **Build** (Push main)

   - Login no ECR
   - Build da imagem Docker
   - Tag: `<commit-sha>` + `latest`
   - Push para ECR
   - Scan de vulnerabilidades

3. **Deploy Staging** (automático)

   - Atualizar Task Definition
   - Deploy no ECS (staging)
   - Wait for service stability
   - Health check (30s)

4. **Deploy Production** (aprovação manual)
   - Atualizar Task Definition
   - Deploy no ECS (prod)
   - Wait for service stability
   - Health check

### Variáveis de Ambiente

```bash
NODE_ENV=staging|production
COMMIT_SHA=<git-commit-sha>
PORT=3000
```

## 🌐 Ambientes

### Staging

- **URL**: `http://lacrei-staging-alb-xxx.sa-east-1.elb.amazonaws.com`
- **Deploy**: Automático (push na main)
- **Instâncias**: 1x t3.micro
- **Logs**: CloudWatch `/ecs/lacrei-app`

### Production

- **URL**: `http://lacrei-prod-alb-xxx.sa-east-1.elb.amazonaws.com`
- **Deploy**: Manual (aprovação no GitHub)
- **Instâncias**: 1x t3.micro (escalável)
- **Logs**: CloudWatch `/ecs/lacrei-app-prod`

## 📊 Observabilidade

### CloudWatch Logs

```bash
# Ver logs do staging
aws logs tail /ecs/lacrei-app --follow

# Ver logs do production
aws logs tail /ecs/lacrei-app-prod --follow
```

### Health Check

- **Endpoint**: `/status`
- **Intervalo**: 30s
- **Timeout**: 5s
- **Healthy Threshold**: 2
- **Unhealthy Threshold**: 2

### Resposta do `/status`:

```json
{
  "ok": true,
  "env": "staging",
  "version": "abc123def",
  "timestamp": "2025-10-17T19:30:00.000Z"
}
```

## 🔙 Processo de Rollback

### Método 1: Via GitHub Actions (Recomendado)

1. Acessar: `Actions` > `CI/CD Pipeline` > `Run workflow`
2. Informar o commit SHA anterior
3. Aprovar deploy em produção

### Método 2: Via AWS Console

```bash
# 1. Listar revisões da task definition
aws ecs list-task-definitions --family-prefix lacrei-task

# 2. Atualizar service para revisão anterior
aws ecs update-service \
  --cluster lacrei-cluster \
  --service lacrei-service \
  --task-definition lacrei-task:5  # revisão anterior

# 3. Aguardar estabilização
aws ecs wait services-stable \
  --cluster lacrei-cluster \
  --services lacrei-service
```

### Método 3: Via Terraform

```bash
# Reverter para imagem anterior no variables.tf
container_image = "xxxx.dkr.ecr.sa-east-1.amazonaws.com/lacrei-api:<sha-anterior>"

# Aplicar mudança
terraform apply -auto-approve
```

### Tempo de Rollback

- **Staging**: ~2 minutos
- **Production**: ~3 minutos (com health checks)

## 🏃 Como Rodar Localmente

### Pré-requisitos

```bash
node >= 18
npm >= 9
docker >= 24
```

### Setup Local

```bash
# Clonar repositório
git clone https://github.com/victorbrandaao/lacrei-devops-challenge.git
cd lacrei-devops-challenge

# Instalar dependências
npm install

# Rodar testes
npm test

# Iniciar aplicação
npm start
```

### Rodar com Docker

```bash
# Build
docker build -t lacrei-api .

# Run
docker run -p 3000:3000 \
  -e NODE_ENV=development \
  -e COMMIT_SHA=local \
  lacrei-api

# Testar
curl http://localhost:3000/status
```

## ☁️ Deploy da Infraestrutura

### Pré-requisitos AWS

```bash
# Configurar AWS CLI
aws configure

# Criar bucket S3 para Terraform state
aws s3 mb s3://lacrei-terraform-state --region sa-east-1
```

### Deploy com Terraform

```bash
cd lacrei-infra

# Inicializar
terraform init

# Planejar (staging)
terraform plan -var="environment=staging"

# Aplicar (staging)
terraform apply -var="environment=staging" -auto-approve

# Aplicar (production)
terraform apply -var="environment=production" -auto-approve

# Outputs
terraform output alb_dns_name
terraform output ecr_repository_url
```

## 🔧 Configuração de Secrets no GitHub

```bash
# Navegar: Settings > Secrets and variables > Actions > New repository secret

AWS_ACCESS_KEY_ID=<sua-access-key>
AWS_SECRET_ACCESS_KEY=<sua-secret-key>
AWS_REGION=sa-east-1
```

## 📈 Melhorias Futuras

- [ ] Implementar Auto Scaling (CPU/Memory based)
- [ ] Adicionar AWS WAF no ALB
- [ ] Configurar AWS Secrets Manager para secrets runtime
- [ ] Implementar Blue/Green deployment com CodeDeploy
- [ ] Adicionar Prometheus + Grafana para métricas
- [ ] Configurar alertas SNS/Slack
- [ ] Implementar chaos engineering (testes de resiliência)
- [ ] Multi-região com Route53 failover

## 💳 Integração com Assas (Proposta)

A integração com a API da Assas para split de pagamento seria implementada seguindo esta arquitetura:

```
API Lacrei → API Assas (Split Payment)
    ↓
1. Criar cobrança (POST /v3/payments)
2. Configurar split rules:
   - Percentual para profissional
   - Percentual para Lacrei (taxa)
3. Webhook para status de pagamento
4. Armazenar transaction_id + status no DB
```

### Variáveis de ambiente adicionais:

```bash
ASSAS_API_KEY=<secret-via-secrets-manager>
ASSAS_WEBHOOK_SECRET=<secret-via-secrets-manager>
ASSAS_ENVIRONMENT=sandbox|production
```

## 📝 Registro de Decisões Técnicas

### Por que ECS on EC2 ao invés de Fargate?

- Custo menor para workloads pequenos
- Maior controle sobre instâncias
- Possibilidade de otimização futura

### Por que não usar CodePipeline?

- GitHub Actions mais familiar para desenvolvedores
- Integração nativa com repositório
- Maior flexibilidade e visibilidade

### Por que multi-stage Docker build?

- Reduz tamanho final da imagem
- Separa dependências de build/runtime
- Melhora segurança

## 🐛 Erros Encontrados e Soluções

| Erro                   | Solução                                    |
| ---------------------- | ------------------------------------------ |
| Task não inicia no ECS | Verificar IAM role e ECR permissions       |
| Health check falha     | Ajustar timeout e intervalo para 30s       |
| ALB 502 Bad Gateway    | Security Group não permitia tráfego do ALB |
| Terraform state lock   | Usar S3 backend com DynamoDB lock          |

## 🤝 Contribuindo

Este projeto foi desenvolvido como parte do desafio técnico da Lacrei Saúde, demonstrando capacidade de criar infraestrutura segura, escalável e bem documentada.

## 📄 Licença

MIT License - Desenvolvido para Lacrei Saúde

---

**Desenvolvido com 💙 para a Lacrei Saúde**
