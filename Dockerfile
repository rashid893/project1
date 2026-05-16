# ============================================
# Stage 1: Install dependencies
# ============================================
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --only=production && \
    cp -R node_modules /prod_modules && \
    npm ci

# ============================================
# Stage 2: Run tests (CI layer — not in final image)
# ============================================
FROM node:20-alpine AS test
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm test

# ============================================
# Stage 3: Production image
# ============================================
FROM node:20-alpine AS production

# Security: run as non-root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only production deps
COPY --from=deps /prod_modules ./node_modules
COPY src/ ./src/
COPY package.json ./

# Metadata
ARG APP_VERSION=unknown
ARG BUILD_SHA=unknown
ENV APP_VERSION=${APP_VERSION}
ENV BUILD_SHA=${BUILD_SHA}
ENV NODE_ENV=production
ENV PORT=3000

LABEL maintainer="devops-team"
LABEL version="${APP_VERSION}"
LABEL description="CI/CD Pipeline Demo API"

# Drop to non-root
USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/server.js"]
