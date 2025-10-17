# Guia de Setup Rápido

## 1. Pré-requisitos
- AWS CLI configurado (`aws configure`)
- Terraform >= 1.5.0
- Docker instalado
- Node.js 18+

## 2. Setup AWS

```bash
# Criar bucket S3 para Terraform state
aws s3 mb s3://lacrei-terraform-state --region sa-east-1

# Criar usuário IAM com permissões necessárias
aws iam create-user --user-name lacrei-cicd
aws iam attach-user-policy --user-name lacrei-cicd \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
aws iam attach-user-policy --user-name lacrei-cicd \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
aws iam create-access-key --user-name lacrei-cicd
```

## 3. Configurar GitHub Secrets

No repositório GitHub: `Settings` > `Secrets and variables` > `Actions`

Adicionar:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## 4. Deploy da Infraestrutura

```bash
cd lacrei-infra

# Staging
terraform init
terraform workspace new staging || terraform workspace select staging
terraform apply -var="environment=staging" -auto-approve

# Production
terraform workspace new production || terraform workspace select production
terraform apply -var="environment=production" -auto-approve
```

## 5. Primeiro Deploy

```bash
# Push para main branch
git add .
git commit -m "Initial setup"
git push origin main

# Acompanhar no GitHub Actions
# https://github.com/victorbrandaao/lacrei-devops-challenge/actions
```

## 6. Verificar Deploy

```bash
# Pegar URL do ALB
terraform output alb_dns_name

# Testar endpoint
curl http://<alb-dns-name>/status
```

## 7. Monitoramento

```bash
# Ver logs
aws logs tail /ecs/lacrei-app --follow

# Status do serviço
aws ecs describe-services \
  --cluster lacrei-cluster \
  --services lacrei-service
```

## Troubleshooting

### Task não inicia
```bash
# Verificar logs do ECS
aws ecs describe-tasks \
  --cluster lacrei-cluster \
  --tasks <task-arn>

# Verificar ECR login
aws ecr get-login-password --region sa-east-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.sa-east-1.amazonaws.com
```

### Health check falha
```bash
# SSH na instância EC2
aws ssm start-session --target <instance-id>

# Verificar container
docker ps
docker logs <container-id>
```
