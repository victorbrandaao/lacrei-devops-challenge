# secrets.tf - AWS Secrets Manager

resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${var.project_name}-app-secrets"
  description             = "Credenciais sensíveis da aplicação"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-secrets"
    Environment = "staging"
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets_version" {
  secret_id = aws_secretsmanager_secret.app_secrets.id

  secret_string = jsonencode({
    DATABASE_URL = "postgresql://user:pass@host:5432/db"
    API_KEY      = "your-api-key-placeholder"
    JWT_SECRET   = "your-jwt-secret-placeholder"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Permissão para ECS Task acessar secrets
resource "aws_iam_role_policy" "ecs_task_secrets_policy" {
  name = "${var.project_name}-task-secrets-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.app_secrets.arn
      }
    ]
  })
}

output "secrets_manager_arn" {
  description = "ARN do Secrets Manager"
  value       = aws_secretsmanager_secret.app_secrets.arn
  sensitive   = true
}
