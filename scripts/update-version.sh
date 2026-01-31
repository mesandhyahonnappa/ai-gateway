#!/bin/bash

# Helper script to update LiteLLM version across all files
# Usage: ./scripts/update-version.sh <new-version-tag>
# Example: ./scripts/update-version.sh main-v1.82.0-nightly

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ -z "$1" ]; then
    echo -e "${RED}Error: Version tag required${NC}"
    echo ""
    echo "Usage: $0 <version-tag>"
    echo ""
    echo "Examples:"
    echo "  $0 main-v1.82.0-nightly"
    echo "  $0 v1.82.0"
    echo ""
    echo "To find available versions:"
    echo "  Visit: https://hub.docker.com/r/berriai/litellm/tags"
    exit 1
fi

NEW_VERSION=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR" || exit 1

VERSION_FILE="$PROJECT_DIR/VERSION"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"

# Read current version
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(grep -v '^#' "$VERSION_FILE" | head -1 | tr -d '[:space:]')
    echo -e "Current version: ${BLUE}$CURRENT_VERSION${NC}"
else
    CURRENT_VERSION="unknown"
    echo -e "${YELLOW}Warning: VERSION file not found${NC}"
fi

echo -e "New version: ${GREEN}$NEW_VERSION${NC}"
echo ""

# Confirm
read -p "Update to version $NEW_VERSION? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Update VERSION file
if [ -f "$VERSION_FILE" ]; then
    # Update the version line (skip comments)
    sed -i.bak "s/^[^#].*/$NEW_VERSION/" "$VERSION_FILE"
    rm -f "$VERSION_FILE.bak"
    echo -e "${GREEN}✅ Updated VERSION file${NC}"
else
    echo "$NEW_VERSION" > "$VERSION_FILE"
    echo -e "${GREEN}✅ Created VERSION file${NC}"
fi

# Update docker-compose.yml
if [ -f "$COMPOSE_FILE" ]; then
    # Update both image tags
    sed -i.bak "s|image: docker\.litellm\.ai/berriai/litellm:[^ ]*|image: docker.litellm.ai/berriai/litellm:$NEW_VERSION|g" "$COMPOSE_FILE"
    rm -f "$COMPOSE_FILE.bak"
    echo -e "${GREEN}✅ Updated docker-compose.yml${NC}"
else
    echo -e "${RED}Error: docker-compose.yml not found${NC}"
    exit 1
fi

# Verify changes
echo ""
echo -e "${BLUE}Verification:${NC}"
echo "VERSION file:"
grep -v '^#' "$VERSION_FILE" | head -1

echo ""
echo "docker-compose.yml image tags:"
grep "image:.*litellm" "$COMPOSE_FILE" | sed 's/^/  /'

echo ""
echo -e "${GREEN}✅ Version update complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review the changes: git diff"
echo "  2. Test the new version: ./scripts/update-litellm.sh"
echo "  3. Commit changes: git add VERSION docker-compose.yml && git commit -m 'Update LiteLLM to $NEW_VERSION'"
