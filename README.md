# LiteLLM Proxy Deployment

This repository contains the configuration and deployment setup for LiteLLM Proxy with separate Admin UI and API instances.

## Architecture

- **Admin Instance** (`litellm-admin`): Port 4001
  - Admin UI and management endpoints
  - No LLM API endpoints
  - Recommended to be behind VPN/internal network

- **API Instance** (`litellm-api`): Port 4000
  - Serves LLM API requests
  - No Admin UI or admin endpoints
  - Publicly accessible for organizations

Both instances share the same database and configuration.

## Quick Start

1. **Set up environment variables** (create `.env` file or export):
   ```bash
   export AZURE_API_BASE="https://your-resource-name.openai.azure.com/"
   export AZURE_API_KEY="your-azure-api-key-here"
   ```

2. **Start services**:
   ```bash
   docker-compose up -d
   ```

3. **Access services**:
   - Admin UI: http://localhost:4001/ui
     - Username: `admin`
     - Password: Your `LITELLM_MASTER_KEY` (from `litellm_config.yaml`)
   - API: http://localhost:4000

## Version Management

This project uses **pinned version tags** instead of `main-latest` for better stability, traceability, and rollback capability.

- **Current version**: Stored in `VERSION` file
- **Version tags**: Explicitly set in `docker-compose.yml`
- **Why pinned versions?**: Predictable deployments, easier debugging, safer rollbacks

### Check for New Versions

```bash
./scripts/check-new-version.sh
```

This will compare your current version with the latest available and notify you if an update is available.

### Update to a New Version

**Option 1: Using the helper script (recommended)**

```bash
./scripts/update-version.sh <version-tag>
# Example:
./scripts/update-version.sh main-v1.82.0-nightly
```

This automatically updates:
- `VERSION` file
- Both image tags in `docker-compose.yml`

**Option 2: Manual update**

1. Check available versions: https://hub.docker.com/r/berriai/litellm/tags
2. Update `VERSION` file with the desired version
3. Update both `image:` tags in `docker-compose.yml`
4. Run the update script (below)

### Deploy an Update

After updating the version, deploy it:

```bash
./scripts/update-litellm.sh
```

This script will:
- ✅ Backup current configuration
- ✅ Pull the specified version images
- ✅ Perform rolling updates (one service at a time)
- ✅ Run health checks
- ✅ Clean up old images

### Automated CI/CD Version Monitoring

The repository includes a GitHub Actions workflow that:
- Runs daily checks comparing your pinned version with the latest available
- Validates docker-compose configuration
- Verifies version consistency across files
- Tests container startup
- Creates GitHub issues when new versions are available

**Workflow triggers:**
- Daily at 3:00 AM UTC (configurable in `.github/workflows/update-litellm.yml`)
- Manual trigger from GitHub Actions UI
- On push to `main`/`master` when docker-compose.yml or VERSION file changes

**Workflow behavior:**
- Compares your current version (from `VERSION` file) with `main-latest`
- Creates a GitHub issue if a newer version is detected
- Provides clear instructions on how to update
- No automatic deployments - you maintain control

**To use:**
1. Push this repository to GitHub
2. The workflow will run automatically on schedule
3. Review GitHub issues created when updates are available
4. Use `./scripts/update-version.sh` to update version
5. Run `./scripts/update-litellm.sh` to deploy

### Health Checks

Run health checks to verify services are running correctly:

```bash
./scripts/health-check.sh
```

Or check manually:
```bash
# Check container status
docker-compose ps

# Check logs
docker-compose logs -f

# Check specific service
docker-compose logs litellm-api
```

## Configuration

### Docker Compose

Edit `docker-compose.yml` to:
- Change port mappings
- Update environment variables
- Modify health check settings

### LiteLLM Config

Edit `litellm_config.yaml` to:
- Add/modify models
- Configure database settings
- Update master key
- Set up model parameters

**Important:** After changing `litellm_config.yaml`, restart services:
```bash
docker-compose restart
```

## Maintenance

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f litellm-api
docker-compose logs -f litellm-admin
```

### Stop Services
```bash
docker-compose down
```

### Restart Services
```bash
docker-compose restart
```

### Clean Up
```bash
# Remove containers and networks
docker-compose down

# Remove containers, networks, and volumes
docker-compose down -v

# Remove unused images
docker image prune -a
```

## Troubleshooting

### "Authentication Error, Not connected to DB!"
- Verify `DATABASE_URL` is correct in `litellm_config.yaml`
- Check database connectivity
- Ensure database exists and is accessible

### Health checks failing
- Check container logs: `docker-compose logs`
- Verify ports are not in use: `lsof -i :4000 -i :4001`
- Ensure health check endpoints are accessible

### Update failed
- Check update log in `backups/update-*.log`
- Verify network connectivity for pulling images
- Check disk space: `df -h`

## Security Recommendations

1. **Restrict Admin Access**: 
   - Limit access to port 4001 (Admin UI) using firewall rules
   - Use VPN or private network for admin instance
   - Implement reverse proxy with authentication

2. **Secrets Management**:
   - Use environment variables for sensitive data
   - Never commit secrets to git
   - Use secret management tools in production

3. **Network Security**:
   - Keep API instance (4000) accessible for organizations
   - Keep Admin instance (4001) internal/restricted
   - Use HTTPS in production (configure reverse proxy)

## Backup

Backups are automatically created in the `backups/` directory when running the update script. To manually backup:

```bash
mkdir -p backups
cp docker-compose.yml backups/docker-compose.backup-$(date +%Y%m%d-%H%M%S).yml
cp litellm_config.yaml backups/litellm_config.backup-$(date +%Y%m%d-%H%M%S).yaml
```

## File Structure

```
.
├── docker-compose.yml          # Docker Compose configuration (with version tags)
├── litellm_config.yaml         # LiteLLM configuration
├── VERSION                     # Current version tracking (see Version Management)
├── scripts/
│   ├── update-litellm.sh      # Deployment update script
│   ├── update-version.sh      # Version update helper script
│   ├── check-new-version.sh   # Check for new versions
│   └── health-check.sh        # Health check script
├── .github/
│   └── workflows/
│       └── update-litellm.yml  # CI/CD version monitoring workflow
├── backups/                    # Backup directory (auto-created)
└── README.md                   # This file
```

## Version Management Best Practices

1. **Always use pinned versions in production** - Don't use `main-latest` for production deployments
2. **Update versions deliberately** - Test new versions before deploying to production
3. **Keep versions in sync** - Ensure `VERSION` file and `docker-compose.yml` use the same version
4. **Document changes** - Commit version updates with clear messages
5. **Test updates** - Use the health check script after updating

## Additional Resources

- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
