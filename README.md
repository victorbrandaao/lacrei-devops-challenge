# Lacrei DevOps Challenge

Sistema de CI/CD com infraestrutura AWS para deploy automatizado.

## Arquitetura

- **CI/CD**: GitHub Actions (test → build → staging → production)
- **Infra**: AWS ECS (EC2), ALB, ECR, CloudWatch

# Lacrei DevOps Challenge

Aplicação Node.js com CI/CD e infraestrutura preparada em Terraform.

Resumo rápido

- Serviço: Node.js + Express (endpoint /status)
- Container: Docker (multi-stage, non-root)
- CI: GitHub Actions (testes + build)
- Infra: Terraform (AWS - ECR, ECS, ALB)

Execute localmente

1. Instale dependências e rode testes:

```bash
npm install
npm test
```

2. Inicie a aplicação localmente:

```bash
npm start
# abre http://localhost:3000/status
```

Docker

```bash
docker build -t lacrei-api .
docker run --rm -p 3000:3000 lacrei-api
```

Provisionamento (Terraform)

```bash
cd lacrei-infra
terraform init
terraform plan
terraform apply
```

GitHub Actions / Deploy

- A pipeline executa testes e build; o deploy para AWS só será ativado quando a infraestrutura existir e a variável de repositório `DEPLOY_ENABLED` estiver `true`.

Segredos (GitHub Actions)

- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

Observabilidade e healthcheck

- Endpoint de health: `/status` (retorna JSON com ok, env, version e timestamp)
- Logs por CloudWatch quando em AWS

Sobre o autor

- Sou estudante de Engenharia de Software com foco em DevOps.
- Esta solução foi construída com auxílio de ferramentas de IA para acelerar implementação e revisão; todas as decisões e o código final foram adaptados e revisados manualmente.

Licença: MIT
