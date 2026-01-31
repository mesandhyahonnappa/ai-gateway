# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **deployment configuration repository** for LiteLLM Proxy, not an application codebase. It configures a two-instance Docker deployment separating Admin UI (control plane) from API (data plane).

## Architecture

| Service | Port | Purpose |
|---------|------|---------|
| `litellm-admin` | 4001 | Admin UI + management endpoints (internal/VPN) |
| `litellm-api` | 4000 | LLM API requests (public-facing) |

Both instances share the same PostgreSQL database (Neon) and `litellm_config.yaml`.

## Common Commands

```bash
# Start/stop services
docker-compose up -d
docker-compose down

# View logs
docker-compose logs -f
docker-compose logs -f litellm-api

# Check service health
./scripts/health-check.sh

# Update to new LiteLLM version
./scripts/update-version.sh <version-tag>   # e.g., main-v1.82.0-nightly
./scripts/update-litellm.sh                  # Deploy the update

# Check for new versions
./scripts/check-new-version.sh
```

## Key Files

- `docker-compose.yml` - Service definitions with pinned version tags
- `litellm_config.yaml` - LiteLLM configuration (models, database, keys)
- `VERSION` - Tracks current pinned version
- `scripts/` - Deployment and maintenance scripts

## Version Management

Uses **pinned version tags** (not `main-latest`) for stability. Version must be updated in both `VERSION` file and `docker-compose.yml` image tags. The `update-version.sh` script handles this automatically.

## CI/CD

GitHub Actions workflow (`.github/workflows/update-litellm.yml`) runs daily to check for new LiteLLM versions and creates issues when updates are available. No automatic deployments.
