#!/bin/bash
set -e

FAMILY="${1:-lacrei-task}"
REGION="${AWS_REGION:-sa-east-1}"

echo "=========================================="
echo "📋 Task Definition Versions"
echo "=========================================="
echo "Família: $FAMILY"
echo "=========================================="
echo ""

aws ecs list-task-definitions \
  --family-prefix "$FAMILY" \
  --region "$REGION" \
  --sort DESC \
  --max-items 10 \
  --query 'taskDefinitionArns[]' \
  --output table

echo ""
echo "Para fazer rollback manualmente:"
echo "  aws ecs update-service --cluster lacrei-cluster --service lacrei-service --task-definition $FAMILY:VERSION --force-new-deployment"
