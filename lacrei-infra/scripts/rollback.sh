#!/bin/bash
set -e

# ==============================================================================
# Script de Rollback ECS
# Reverte o serviço ECS para a task definition anterior
# ==============================================================================

CLUSTER_NAME="${ECS_CLUSTER:-lacrei-cluster}"
SERVICE_NAME="${ECS_SERVICE:-lacrei-service}"
REGION="${AWS_REGION:-sa-east-1}"

echo "=========================================="
echo "🔄 ECS Rollback Script"
echo "=========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Service: $SERVICE_NAME"
echo "Region: $REGION"
echo "=========================================="

# Obter task definition atual
echo "🔍 Buscando task definition atual..."
CURRENT_TASK=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$REGION" \
  --query 'services[0].taskDefinition' \
  --output text)

if [ -z "$CURRENT_TASK" ]; then
  echo "❌ Erro: Não foi possível encontrar o serviço ECS"
  exit 1
fi

echo "📋 Task definition atual: $CURRENT_TASK"

# Extrair família e versão
FAMILY=$(echo "$CURRENT_TASK" | rev | cut -d'/' -f1 | rev | cut -d':' -f1)
CURRENT_VERSION=$(echo "$CURRENT_TASK" | rev | cut -d':' -f1 | rev)
PREVIOUS_VERSION=$((CURRENT_VERSION - 1))

echo "📦 Família: $FAMILY"
echo "🔢 Versão atual: $CURRENT_VERSION"
echo "🔢 Versão anterior: $PREVIOUS_VERSION"

if [ "$PREVIOUS_VERSION" -lt 1 ]; then
  echo "❌ Erro: Não há versão anterior para fazer rollback"
  exit 1
fi

PREVIOUS_TASK_DEF="${FAMILY}:${PREVIOUS_VERSION}"

echo ""
echo "=========================================="
echo "⚠️  ATENÇÃO: Você está prestes a fazer rollback"
echo "=========================================="
echo "De: $CURRENT_TASK"
echo "Para: $PREVIOUS_TASK_DEF"
echo ""
read -p "Deseja continuar? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Rollback cancelado pelo usuário"
  exit 0
fi

echo ""
echo "🔄 Iniciando rollback..."

aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --task-definition "$PREVIOUS_TASK_DEF" \
  --region "$REGION" \
  --force-new-deployment > /dev/null

echo ""
echo "=========================================="
echo "✅ Rollback iniciado com sucesso!"
echo "=========================================="
echo ""
echo "📊 Acompanhe o status do deployment:"
echo "   aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION"
echo ""
echo "📊 Ou via console:"
echo "   https://console.aws.amazon.com/ecs/v2/clusters/$CLUSTER_NAME/services/$SERVICE_NAME"
echo ""
