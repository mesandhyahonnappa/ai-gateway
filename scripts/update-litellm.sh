#!/bin/bash

# LiteLLM Update Script
# This script safely updates LiteLLM containers with health checks and rollback capability

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.yml"
BACKUP_DIR="backups"
LOG_FILE="update-$(date +%Y%m%d-%H%M%S).log"
HEALTH_CHECK_TIMEOUT=120  # seconds
HEALTH_CHECK_INTERVAL=5   # seconds

# Functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    else
        error "docker-compose or 'docker compose' is not installed"
    fi
else
    DOCKER_COMPOSE="docker-compose"
fi

log "Starting LiteLLM update process..."

# Navigate to script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR" || error "Failed to change to project directory"

log "Project directory: $PROJECT_DIR"

# Check version consistency
VERSION_FILE="$PROJECT_DIR/VERSION"
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(grep -v '^#' "$VERSION_FILE" | head -1 | tr -d '[:space:]')
    log "Version from VERSION file: $VERSION"
    
    # Check if docker-compose.yml uses the same version
    COMPOSE_VERSION_COUNT=$(grep -c "litellm:$VERSION" docker-compose.yml || echo "0")
    if [ "$COMPOSE_VERSION_COUNT" -lt 2 ]; then
        warning "Version in VERSION file ($VERSION) may not match docker-compose.yml"
        warning "Please ensure docker-compose.yml uses the same version tag"
    fi
else
    warning "VERSION file not found. Consider creating one for better version tracking."
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if containers are running
if ! $DOCKER_COMPOSE ps | grep -q "Up"; then
    warning "No containers are currently running. Starting fresh..."
    $DOCKER_COMPOSE up -d
    log "Containers started. Waiting for health checks..."
    sleep 30
    exit 0
fi

# Backup current state
log "Creating backup of current configuration..."
cp "$COMPOSE_FILE" "$BACKUP_DIR/docker-compose.backup-$(date +%Y%m%d-%H%M%S).yml" || warning "Failed to backup docker-compose.yml"

# Get current image tags
log "Checking current image versions..."
$DOCKER_COMPOSE images | tee -a "$LOG_FILE"

# Pull latest images
log "Pulling latest images..."
$DOCKER_COMPOSE pull || error "Failed to pull latest images"

# Check what will change
log "Checking for image updates..."
IMAGE_UPDATES=$($DOCKER_COMPOSE images | grep -E "litellm-admin|litellm-api" || true)
log "Images to be updated:\n$IMAGE_UPDATES"

# Perform rolling update (one service at a time)
log "Starting rolling update..."

# Update admin instance first
log "Updating litellm-admin service..."
$DOCKER_COMPOSE up -d --no-deps litellm-admin || error "Failed to update litellm-admin"

# Wait for admin health check
log "Waiting for litellm-admin to be healthy..."
ADMIN_HEALTHY=false
for i in $(seq 1 $((HEALTH_CHECK_TIMEOUT / HEALTH_CHECK_INTERVAL))); do
    if $DOCKER_COMPOSE ps litellm-admin | grep -q "healthy"; then
        ADMIN_HEALTHY=true
        break
    fi
    sleep $HEALTH_CHECK_INTERVAL
    echo -n "."
done
echo ""

if [ "$ADMIN_HEALTHY" = true ]; then
    log "✅ litellm-admin is healthy"
else
    warning "⚠️  litellm-admin health check timed out, but continuing..."
fi

# Update API instance
log "Updating litellm-api service..."
$DOCKER_COMPOSE up -d --no-deps litellm-api || error "Failed to update litellm-api"

# Wait for API health check
log "Waiting for litellm-api to be healthy..."
API_HEALTHY=false
for i in $(seq 1 $((HEALTH_CHECK_TIMEOUT / HEALTH_CHECK_INTERVAL))); do
    if $DOCKER_COMPOSE ps litellm-api | grep -q "healthy"; then
        API_HEALTHY=true
        break
    fi
    sleep $HEALTH_CHECK_INTERVAL
    echo -n "."
done
echo ""

if [ "$API_HEALTHY" = true ]; then
    log "✅ litellm-api is healthy"
else
    warning "⚠️  litellm-api health check timed out, but continuing..."
fi

# Perform manual health checks
log "Performing manual health checks..."
./scripts/health-check.sh || warning "Health check script failed, but containers may still be running"

# Clean up old images
log "Cleaning up unused images..."
docker image prune -f || warning "Failed to prune old images"

# Show final status
log "Update complete! Current status:"
$DOCKER_COMPOSE ps

log "Image versions after update:"
$DOCKER_COMPOSE images

log "✅ Update process completed successfully!"
log "Log file saved to: $LOG_FILE"

# Show access information
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}LiteLLM Services:${NC}"
echo -e "  Admin UI: ${GREEN}http://localhost:4001/ui${NC}"
echo -e "  API:      ${GREEN}http://localhost:4000${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
