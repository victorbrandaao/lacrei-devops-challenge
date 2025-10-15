# Stage 1: Build
FROM node:18-alpine AS builder

WORKDIR /app

# Copiar apenas package files para cache de dependências
COPY package*.json ./

# Instalar dependências (incluindo dev para testes)
RUN npm ci --omit=dev && \
    npm cache clean --force

# Stage 2: Runtime
FROM node:18-alpine

# Instalar curl para healthcheck
RUN apk add --no-cache curl

# Criar usuário não-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copiar dependências do stage de build
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copiar código da aplicação
COPY --chown=nodejs:nodejs package*.json ./
COPY --chown=nodejs:nodejs src ./src

# Mudar para usuário não-root
USER nodejs

# Expor porta
EXPOSE 3000

# Healthcheck - chama /status a cada 30s
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/status || exit 1

# Comando de inicialização
CMD ["node", "src/server.js"]