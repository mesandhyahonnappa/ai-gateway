# LiteLLM AI Gateway - Learning Guide

This document summarizes the complete setup of LiteLLM as an AI Gateway on Azure.

---

## Table of Contents

1. [What is LiteLLM?](#1-what-is-litellm)
2. [Architecture Overview](#2-architecture-overview)
3. [Local Development Setup](#3-local-development-setup)
4. [Configuration Files](#4-configuration-files)
5. [Azure Resources](#5-azure-resources)
6. [Docker Hub Setup](#6-docker-hub-setup)
7. [GitHub Actions CI/CD](#7-github-actions-cicd)
8. [Azure Container Apps Deployment](#8-azure-container-apps-deployment)
9. [Testing Commands](#9-testing-commands)
10. [Key Learnings](#10-key-learnings)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. What is LiteLLM?

LiteLLM is an **AI Gateway/Proxy** that sits between your applications and LLM providers.

### What LiteLLM Does NOT Do
- ❌ Create or deploy models
- ❌ Give free access to providers
- ❌ Replace provider accounts

### What LiteLLM DOES Do
- ✅ **Unified API** - One format for all providers (OpenAI-compatible)
- ✅ **Virtual Keys** - Create keys per user/app with limits
- ✅ **Load Balancing** - Spread requests across deployments
- ✅ **Fallbacks** - Auto-switch if provider fails
- ✅ **Cost Tracking** - Monitor spend across all providers
- ✅ **Rate Limiting** - Control requests per key
- ✅ **Caching** - Save money on repeated queries
- ✅ **Logging** - Centralized logs for all LLM calls

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        YOUR APPLICATIONS                            │
│   (App 1)      (App 2)      (App 3)      (Mobile App)               │
└──────┬────────────┬────────────┬────────────────┬───────────────────┘
       │            │            │                │
       │     Same API format: POST /v1/chat/completions               │
       ▼            ▼            ▼                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         LiteLLM Gateway                             │
└───────┬───────────────────┬───────────────────┬─────────────────────┘
        │                   │                   │
        ▼                   ▼                   ▼
   ┌─────────┐        ┌──────────┐       ┌───────────┐
   │  Azure  │        │ Anthropic│       │  OpenAI   │
   │ OpenAI  │        │ (Claude) │       │  Direct   │
   └─────────┘        └──────────┘       └───────────┘
```

---

## 2. Architecture Overview

### Final Deployed Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Azure Container Apps                              │
│                    (Central India)                                   │
│                                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                    litellm-dev                               │   │
│   │                                                              │   │
│   │   Admin UI:  https://litellm-dev.xxx.centralindia.azurecontainerapps.io/ui    │
│   │   API:       https://litellm-dev.xxx.centralindia.azurecontainerapps.io/v1    │
│   │                                                              │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                            │                                         │
└────────────────────────────┼─────────────────────────────────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
     ┌─────────────┐  ┌───────────┐  ┌─────────────┐
     │   Azure     │  │  Azure    │  │  Anthropic  │
     │ PostgreSQL  │  │  OpenAI   │  │  (Claude)   │
     │ (Central    │  │ (East US) │  │             │
     │  India)     │  │           │  │             │
     └─────────────┘  └───────────┘  └─────────────┘
```

### Resource Group: mindquest-rg

| Resource | Type | Location |
|----------|------|----------|
| mindquest-db-postgres | PostgreSQL Flexible Server | Central India |
| sandhya-honnappa | Azure OpenAI | East US 2 |
| litellm-dev | Container App | Central India |
| sandhya-projects-dev | Container Apps Environment | Central India |

---

## 3. Local Development Setup

### Prerequisites
- Docker Desktop installed and running
- Azure CLI installed (`brew install azure-cli`)

### Project Structure

```
ai-gateway/
├── .env                        # Secrets (gitignored)
├── .env.example                # Template for secrets
├── .gitignore
├── docker-compose.yml          # Run both services locally
├── docker-compose.admin.yml    # Admin only (Enterprise)
├── docker-compose.api.yml      # API only (Enterprise)
├── Dockerfile                  # Custom image for cloud
├── litellm_config.yaml         # LiteLLM configuration
├── VERSION                     # Pinned LiteLLM version
├── CLAUDE.md                   # Project instructions
├── docs/
│   └── LEARNING-GUIDE.md       # This document
├── infra/
│   └── deploy-container-app.sh # Azure deployment script
├── scripts/
│   ├── health-check.sh         # Local health check
│   └── update-version.sh       # Version update script
└── .github/
    └── workflows/
        ├── build-push-docker.yml  # Build & push to Docker Hub
        ├── deploy-azure.yml       # Deploy to Container Apps
        └── update-litellm.yml     # Check for updates
```

### Running Locally

```bash
# Start LiteLLM
docker-compose up -d

# Check status
docker ps

# View logs
docker-compose logs -f

# Test health
curl http://localhost:4000/health/liveliness

# Test API
curl -X POST "http://localhost:4000/v1/chat/completions" \
  -H "Authorization: Bearer sk-pasand2#" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o-mini", "messages": [{"role": "user", "content": "Hello"}]}'

# Stop
docker-compose down
```

---

## 4. Configuration Files

### .env (Secrets - Never commit!)

```bash
# Database
DATABASE_URL=postgresql://user:password@host:5432/database?sslmode=require

# LiteLLM
LITELLM_MASTER_KEY=sk-your-master-key

# Azure OpenAI
AZURE_API_BASE=https://your-resource.openai.azure.com/
AZURE_API_KEY=your-azure-key

# Anthropic
ANTHROPIC_API_KEY=sk-ant-your-key
```

### litellm_config.yaml

```yaml
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL

model_list:
  # Azure OpenAI - GPT-4o Mini
  - model_name: gpt-4o-mini
    litellm_params:
      model: azure/gpt-4o-mini
      api_base: os.environ/AZURE_API_BASE
      api_key: os.environ/AZURE_API_KEY
      api_version: "2024-08-01-preview"

  # Anthropic - Claude 3.5 Sonnet
  - model_name: claude-sonnet
    litellm_params:
      model: anthropic/claude-sonnet-4-20250514
      api_key: os.environ/ANTHROPIC_API_KEY

  # Anthropic - Claude 3.5 Haiku (fast & cheap)
  - model_name: claude-haiku
    litellm_params:
      model: anthropic/claude-3-5-haiku-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
```

### docker-compose.yml

```yaml
services:
  litellm:
    image: docker.litellm.ai/berriai/litellm:main-v1.81.0-nightly
    container_name: litellm
    ports:
      - "4000:4000"
    volumes:
      - ./litellm_config.yaml:/app/litellm_config.yaml
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY}
      - AZURE_API_BASE=${AZURE_API_BASE:-}
      - AZURE_API_KEY=${AZURE_API_KEY:-}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
    command: --config /app/litellm_config.yaml
    restart: unless-stopped

networks:
  litellm-network:
    driver: bridge
```

### Dockerfile

```dockerfile
FROM docker.litellm.ai/berriai/litellm:main-v1.81.0-nightly
COPY litellm_config.yaml /app/litellm_config.yaml
EXPOSE 4000
CMD ["--config", "/app/litellm_config.yaml"]
```

---

## 5. Azure Resources

### Azure OpenAI Setup

1. **Create Azure OpenAI resource**
   - Azure Portal → Search "Azure OpenAI" → Create
   - Choose region with quota (East US 2, Sweden Central)
   - SKU: Standard S0

2. **Deploy a model**
   - Go to resource → Model deployments → Create
   - Select model: gpt-4o-mini
   - Deployment name: gpt-4o-mini

3. **Get credentials**
   - Keys and Endpoint → Copy Endpoint and Key

### Azure PostgreSQL Setup

1. **Create PostgreSQL Flexible Server**
   - Azure Portal → Search "Azure Database for PostgreSQL"
   - Choose Flexible Server
   - Configure firewall rules

2. **Firewall Rules**
   - Allow Azure services: ✅
   - Add your IP for local development

### AZURE_API_BASE Explained

```
OpenAI (direct):     https://api.openai.com         ← Everyone uses same URL
Azure OpenAI:        https://YOUR-RESOURCE.openai.azure.com  ← Your unique URL
                            ↑
                     AZURE_API_BASE
```

---

## 6. Docker Hub Setup

### Why Docker Hub?
- Free tier (200 pulls/6hr authenticated)
- No monthly cost
- Good for learning

### Setup Steps

1. **Create Docker Hub account**: https://hub.docker.com/
2. **Create repository**: `your-username/litellm-gateway` (Private)
3. **Create Access Token**:
   - Account Settings → Security → New Access Token
   - Permissions: Read & Write

---

## 7. GitHub Actions CI/CD

### Secrets Required

Go to: GitHub Repo → Settings → Secrets and variables → Actions

| Secret | Value |
|--------|-------|
| DOCKERHUB_USERNAME | Your Docker Hub username |
| DOCKERHUB_TOKEN | Docker Hub access token |

### Build & Push Workflow

`.github/workflows/build-push-docker.yml`

Triggers on:
- Push to main (Dockerfile or litellm_config.yaml changes)
- Manual trigger

Actions:
1. Checkout code
2. Login to Docker Hub
3. Build image with config baked in
4. Push to Docker Hub with tags: `latest` and `commit-sha`

---

## 8. Azure Container Apps Deployment

### Why Container Apps?
- Serverless containers
- Auto-scaling
- Pay per use
- Easy deployment

### Deployment via Portal

1. **Create Container Apps Environment**
   - Name: litellm-env
   - Region: Central India (close to database)

2. **Create Container App**
   - Name: litellm-dev
   - Image source: Docker Hub
   - Image: your-username/litellm-gateway:latest
   - Target port: 4000
   - Ingress: External

3. **Environment Variables**
   - DATABASE_URL
   - LITELLM_MASTER_KEY
   - AZURE_API_BASE
   - AZURE_API_KEY
   - ANTHROPIC_API_KEY

4. **PostgreSQL Firewall**
   - Enable: "Allow public access from any Azure service"

### Container Apps vs Local Docker

| Feature | docker-compose (local) | Container Apps (cloud) |
|---------|------------------------|------------------------|
| Mount local files | ✅ Yes | ❌ No |
| Read local .env | ✅ Yes | ❌ No (use Secrets) |
| Custom image needed | No | Yes (for config) |

---

## 9. Testing Commands

### Health Check

```bash
# Local
curl http://localhost:4000/health/liveliness

# Azure
curl https://litellm-dev.xxx.centralindia.azurecontainerapps.io/health/liveliness
```

### Test Azure OpenAI

```bash
curl -X POST "http://localhost:4000/v1/chat/completions" \
  -H "Authorization: Bearer sk-pasand2#" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o-mini", "messages": [{"role": "user", "content": "Hello"}]}'
```

### Test Claude

```bash
curl -X POST "http://localhost:4000/v1/chat/completions" \
  -H "Authorization: Bearer sk-pasand2#" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet", "messages": [{"role": "user", "content": "Hello"}]}'
```

### Test Claude Haiku (Fast)

```bash
curl -X POST "http://localhost:4000/v1/chat/completions" \
  -H "Authorization: Bearer sk-pasand2#" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-haiku", "messages": [{"role": "user", "content": "Hello"}]}'
```

---

## 10. Key Learnings

### LiteLLM Value Proposition
- Still need provider accounts (Azure OpenAI, Anthropic)
- LiteLLM provides unified API, key management, cost tracking
- Benefits: Switch providers without code changes, create virtual keys, set budgets

### Docker Concepts
- **docker-compose.yml**: For running containers locally
- **Dockerfile**: For building custom images
- **Volume mounts**: Local file access (not available in cloud)
- **Environment variables**: Configuration injection

### Azure Concepts
- **Resource Group**: Logical container for resources
- **Container Apps Environment**: Shared hosting for container apps
- **Container Apps**: Serverless container hosting
- **Azure OpenAI**: Microsoft's hosted OpenAI models

### Enterprise vs Free
- Free: Single instance with Admin UI + API
- Enterprise: Separate Admin (control plane) and API (data plane)
- `DISABLE_*` flags are Enterprise features

### Naming Conventions
- Resource groups: `rg-{project}` or `{project}-rg`
- Container Apps: `{project}-{env}` (e.g., litellm-dev)
- Environment: `{project}-env`

---

## 11. Troubleshooting

### Database Connection Failed

```
Error: P1001: Can't reach database server
```

**Solution**: Add IP to PostgreSQL firewall or enable "Allow Azure services"

### Authentication Error

```
litellm.AuthenticationError: Access denied due to invalid subscription key
```

**Solution**: Verify AZURE_API_BASE and AZURE_API_KEY match your Azure OpenAI resource

### Enterprise Feature Error

```
DISABLING LLM API ENDPOINTS is an Enterprise feature
```

**Solution**: Remove DISABLE_* environment variables for free version

### Docker Image Not Found

**Solution**: Verify Docker Hub repository exists and credentials are correct

---

## Endpoints Summary

### Local Development

| Endpoint | URL |
|----------|-----|
| Admin UI | http://localhost:4000/ui |
| API | http://localhost:4000/v1/chat/completions |
| Health | http://localhost:4000/health/liveliness |

### Production (Azure)

| Endpoint | URL |
|----------|-----|
| Admin UI | https://litellm-dev.redsand-15a1b929.centralindia.azurecontainerapps.io/ui |
| API | https://litellm-dev.redsand-15a1b929.centralindia.azurecontainerapps.io/v1/chat/completions |
| Health | https://litellm-dev.redsand-15a1b929.centralindia.azurecontainerapps.io/health/liveliness |

---

## Next Steps

1. **Explore Admin UI** - Create virtual keys, view usage analytics
2. **Add more models** - Update litellm_config.yaml
3. **Set up fallbacks** - Configure automatic provider switching
4. **Implement caching** - Reduce costs on repeated queries
5. **Create budgets** - Set spending limits per key

---

*Document created: February 2, 2026*
*LiteLLM Version: main-v1.81.0-nightly*
