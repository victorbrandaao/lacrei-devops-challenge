# Lacrei DevOps Challenge

Sistema de CI/CD com infraestrutura AWS para deploy automatizado.

## Arquitetura

- **CI/CD**: GitHub Actions (test → build → staging → production)
- **Infra**: AWS ECS (EC2), ALB, ECR, CloudWatch
- **IaC**: Terraform
- **App**: Node.js 18 + Express

## Estrutura

```
.
├── .github/workflows/ci.yml    # Pipeline
├── src/
│   ├── app.js
│   ├── server.js
│   ├── routes/status.js
│   └── __tests__/
├── lacrei-infra/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── Dockerfile
└── package.json
```

## Segurança

- Secrets no GitHub
- Container non-root
- ECR vulnerability scanning
- Security Groups restritivos
- HTTPS/TLS com ACM
- IAM least privilege

## Pipeline

1. **Test**: Jest (100% coverage)
2. **Build**: Docker → ECR
3. **Staging**: Deploy automático
4. **Production**: Aprovação manual

## Como Rodar

**Local:**

```bash
npm install
npm test
npm start
```

**Docker:**

```bash
docker build -t lacrei-api .
docker run -p 3000:3000 lacrei-api
```

## Deploy Infra

```bash
cd lacrei-infra
terraform init
terraform plan
terraform apply
```

**GitHub Secrets necessários:**

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## Rollback

**Via ECS:**

```bash
aws ecs update-service \
  --cluster lacrei-cluster \
  --service lacrei-service \
  --task-definition lacrei-task:5
```

**Via Terraform:**

```bash
# Atualizar container_image em variables.tf
terraform apply
```

## Observabilidade

**Logs:**

```bash
aws logs tail /ecs/lacrei-app --follow
```

**Health check**: `/status` (30s interval)

**Resposta:**

```json
{
  "ok": true,
  "env": "staging",
  "version": "abc123",
  "timestamp": "2025-10-17T19:30:00Z"
}
```

## Decisões Técnicas

- **ECS EC2 vs Fargate**: Escolhi EC2 por custo menor
- **GitHub Actions vs CodePipeline**: Melhor integração com repo
- **Multi-stage Docker**: Reduz tamanho e melhora segurança

## Licença

MIT
