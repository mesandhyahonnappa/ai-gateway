#!/bin/bash

# Check for new LiteLLM versions
# This script checks if there's a newer version available than what's in VERSION file

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="$PROJECT_DIR/VERSION"
REGISTRY="docker.litellm.ai/berriai/litellm"

# Read current version
if [ ! -f "$VERSION_FILE" ]; then
    echo -e "${YELLOW}Warning: VERSION file not found. Creating with main-latest...${NC}"
    echo "main-latest" > "$VERSION_FILE"
fi

CURRENT_VERSION=$(grep -v '^#' "$VERSION_FILE" | head -1 | tr -d '[:space:]')
CURRENT_IMAGE="$REGISTRY:$CURRENT_VERSION"

echo "Checking for new LiteLLM versions..."
echo "Current version: $CURRENT_VERSION"
echo ""

# Check latest tag
echo "Fetching available tags..."
LATEST_TAG=""

# Try to get tags from Docker registry
# Note: This requires docker to be running and the registry to be accessible
if command -v docker &> /dev/null; then
    echo "Pulling image to check latest tag..."
    docker pull "$REGISTRY:main-latest" > /dev/null 2>&1 || echo "Could not pull main-latest"
    
    # Get the digest of main-latest
    LATEST_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$REGISTRY:main-latest" 2>/dev/null | cut -d'@' -f2 || echo "")
    CURRENT_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$CURRENT_IMAGE" 2>/dev/null | cut -d'@' -f2 || echo "")
    
    if [ -n "$LATEST_DIGEST" ] && [ -n "$CURRENT_DIGEST" ]; then
        if [ "$LATEST_DIGEST" != "$CURRENT_DIGEST" ]; then
            echo -e "${YELLOW}⚠️  New version available!${NC}"
            echo ""
            echo "Current version digest: $CURRENT_DIGEST"
            echo "Latest version digest:  $LATEST_DIGEST"
            echo ""
            echo "To update:"
            echo "  1. Check available tags: https://hub.docker.com/r/berriai/litellm/tags"
            echo "  2. Update VERSION file with the desired version"
            echo "  3. Update docker-compose.yml image tags"
            echo "  4. Run: ./scripts/update-litellm.sh"
            exit 1
        else
            echo -e "${GREEN}✅ You are on the latest version${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Could not compare versions. Checking if current image exists...${NC}"
        if docker pull "$CURRENT_IMAGE" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Current version image exists and is pullable${NC}"
        else
            echo -e "${YELLOW}⚠️  Current version image may not exist or be accessible${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠️  Docker not available. Cannot check for new versions.${NC}"
    echo ""
    echo "Manual check:"
    echo "  1. Visit: https://hub.docker.com/r/berriai/litellm/tags"
    echo "  2. Compare with version in VERSION file: $CURRENT_VERSION"
    exit 0
fi

echo ""
echo -e "${BLUE}Tip:${NC} To see all available versions, visit:"
echo "  https://hub.docker.com/r/berriai/litellm/tags"
