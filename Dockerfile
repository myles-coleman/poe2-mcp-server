# syntax=docker/dockerfile:1

# Multi-arch base image — supports linux/amd64 and linux/arm64 (ARM).
# Pinned to Node 22 to satisfy the "engines" requirement in package.json.

# ---- Build stage ----
FROM node:22-alpine AS builder

WORKDIR /app

# Install dependencies first to leverage Docker layer caching.
COPY package.json package-lock.json .npmrc ./
RUN npm ci

# Copy sources and compile TypeScript -> dist/.
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# Strip dev dependencies so only runtime deps are carried forward.
RUN npm prune --omit=dev

# ---- Runtime stage ----
FROM node:22-alpine AS runtime

ENV NODE_ENV=production

WORKDIR /app

# Run as the non-root user that ships with the node image.
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/package.json ./package.json

USER node

# MCP server communicates over stdio (stdin/stdout).
ENTRYPOINT ["node", "dist/index.js"]
