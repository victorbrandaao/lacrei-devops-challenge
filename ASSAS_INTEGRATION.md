# Integração Assas - Proposta de Arquitetura

## Visão Geral

Sistema de split de pagamento para distribuir valores entre profissionais de saúde e a plataforma Lacrei.

## Fluxo de Pagamento

```
┌─────────┐       ┌──────────┐       ┌─────────────┐       ┌──────────────┐
│ Cliente │ ----> │   API    │ ----> │  API Assas  │ ----> │   Webhook    │
│ (App)   │       │  Lacrei  │       │ (Split Pay) │       │  (Callback)  │
└─────────┘       └──────────┘       └─────────────┘       └──────────────┘
     |                 |                     |                      |
     |                 |                     |                      v
     |                 |                     |            ┌──────────────────┐
     |                 |                     |            │ Atualizar Status │
     |                 |                     |            │   no Banco de    │
     |                 |                     |            │      Dados       │
     |                 |                     |            └──────────────────┘
     |                 v                     v
     |        ┌────────────────┐   ┌─────────────────┐
     |        │  Salvar no DB  │   │  Confirmar      │
     |        │  transaction_id│   │  Pagamento      │
     |        └────────────────┘   └─────────────────┘
     v
┌──────────────┐
│ Receber Link │
│  Pagamento   │
└──────────────┘
```

## Implementação

### 1. Endpoint de Criação de Cobrança

```javascript
// src/routes/payment.js
const express = require('express');
const router = express.Router();
const axios = require('axios');

router.post('/create-charge', async (req, res) => {
  const { amount, customerId, professionalId } = req.body;

  const assasConfig = {
    baseURL: process.env.ASSAS_API_URL,
    headers: {
      'access_token': process.env.ASSAS_API_KEY,
      'Content-Type': 'application/json'
    }
  };

  try {
    // Calcular split (exemplo: 70% profissional, 30% Lacrei)
    const professionalAmount = amount * 0.70;
    const lacreiFee = amount * 0.30;

    // Criar cobrança com split
    const charge = await axios.post('/v3/payments', {
      customer: customerId,
      billingType: 'CREDIT_CARD',
      value: amount,
      dueDate: new Date().toISOString().split('T')[0],
      description: 'Consulta Lacrei Saúde',
      split: [
        {
          walletId: professionalId, // Wallet do profissional
          fixedValue: professionalAmount
        }
      ]
    }, assasConfig);

    // Salvar no banco de dados
    await db.transactions.create({
      assasId: charge.data.id,
      amount,
      status: 'PENDING',
      professionalId,
      customerId,
      professionalAmount,
      lacreiFee
    });

    res.json({
      success: true,
      paymentUrl: charge.data.invoiceUrl,
      transactionId: charge.data.id
    });

  } catch (error) {
    console.error('Erro ao criar cobrança:', error);
    res.status(500).json({ error: 'Erro ao processar pagamento' });
  }
});

module.exports = router;
```

### 2. Webhook para Atualização de Status

```javascript
// src/routes/webhook.js
const express = require('express');
const router = express.Router();
const crypto = require('crypto');

router.post('/assas-webhook', async (req, res) => {
  const { event, payment } = req.body;

  // Validar assinatura do webhook
  const signature = req.headers['asaas-signature'];
  const expectedSignature = crypto
    .createHmac('sha256', process.env.ASSAS_WEBHOOK_SECRET)
    .update(JSON.stringify(req.body))
    .digest('hex');

  if (signature !== expectedSignature) {
    return res.status(401).json({ error: 'Invalid signature' });
  }

  // Atualizar status da transação
  await db.transactions.update(
    { status: payment.status },
    { where: { assasId: payment.id } }
  );

  // Enviar notificação ao profissional e cliente
  if (payment.status === 'CONFIRMED') {
    await notifyProfessional(payment.id);
    await notifyCustomer(payment.id);
  }

  res.json({ received: true });
});

module.exports = router;
```

### 3. Variáveis de Ambiente

```bash
# .env
ASSAS_API_URL=https://sandbox.asaas.com/api
ASSAS_API_KEY=<sua-api-key-via-secrets-manager>
ASSAS_WEBHOOK_SECRET=<webhook-secret>
ASSAS_ENVIRONMENT=sandbox
```

### 4. Secrets Manager (AWS)

```bash
# Criar secrets no AWS Secrets Manager
aws secretsmanager create-secret \
  --name lacrei/assas/api-key \
  --secret-string "<api-key>"

aws secretsmanager create-secret \
  --name lacrei/assas/webhook-secret \
  --secret-string "<webhook-secret>"
```

```javascript
// Carregar secrets na aplicação
const AWS = require('aws-sdk');
const secretsManager = new AWS.SecretsManager({ region: 'sa-east-1' });

async function loadSecrets() {
  const apiKey = await secretsManager.getSecretValue({ 
    SecretId: 'lacrei/assas/api-key' 
  }).promise();
  
  const webhookSecret = await secretsManager.getSecretValue({ 
    SecretId: 'lacrei/assas/webhook-secret' 
  }).promise();

  process.env.ASSAS_API_KEY = apiKey.SecretString;
  process.env.ASSAS_WEBHOOK_SECRET = webhookSecret.SecretString;
}
```

## Infraestrutura Adicional

### IAM Policy para Secrets Manager

```hcl
# lacrei-infra/secrets.tf
resource "aws_iam_policy" "secrets_access" {
  name        = "lacrei-secrets-access"
  description = "Allow ECS tasks to read secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:sa-east-1:*:secret:lacrei/assas/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_secrets" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}
```

## Testes

### Teste com Mock (Postman/Jest)

```javascript
// __tests__/payment.test.js
describe('Payment Integration', () => {
  it('should create charge with split', async () => {
    const mockAssas = nock('https://sandbox.asaas.com')
      .post('/api/v3/payments')
      .reply(200, {
        id: 'pay_123',
        invoiceUrl: 'https://asaas.com/invoice/abc',
        status: 'PENDING'
      });

    const response = await request(app)
      .post('/api/create-charge')
      .send({
        amount: 100,
        customerId: 'cus_123',
        professionalId: 'prof_456'
      });

    expect(response.status).toBe(200);
    expect(response.body.paymentUrl).toBeDefined();
  });
});
```

## Documentação Assas

- **API Docs**: https://docs.asaas.com/reference/criar-nova-cobranca
- **Split Payment**: https://docs.asaas.com/docs/split-de-pagamentos
- **Webhooks**: https://docs.asaas.com/docs/webhooks

## Considerações de Segurança

1. **API Keys**: Nunca commitar no código, usar Secrets Manager
2. **Webhook Signature**: Sempre validar assinatura HMAC
3. **HTTPS Only**: Webhook endpoint deve ser HTTPS
4. **Rate Limiting**: Implementar rate limit nas rotas de pagamento
5. **Logs**: Nunca logar dados sensíveis (cartão, CPF)

## Monitoramento

```javascript
// CloudWatch metrics
const AWS = require('aws-sdk');
const cloudwatch = new AWS.CloudWatch();

async function trackPayment(status) {
  await cloudwatch.putMetricData({
    Namespace: 'Lacrei/Payments',
    MetricData: [{
      MetricName: 'PaymentStatus',
      Value: 1,
      Unit: 'Count',
      Dimensions: [{
        Name: 'Status',
        Value: status
      }]
    }]
  }).promise();
}
```

## Roadmap

- [ ] Implementar retry logic para falhas de API
- [ ] Adicionar queue (SQS) para processamento assíncrono
- [ ] Dashboard de pagamentos em tempo real
- [ ] Reconciliação automática com extrato Assas
- [ ] Suporte a múltiplos métodos de pagamento (Pix, Boleto)
