#!/bin/bash

# LiteLLM Health Check Script
# Validates that both admin and API services are responding correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ADMIN_URL="http://localhost:4001"
API_URL="http://localhost:4000"
TIMEOUT=10
RETRIES=3

# Functions
check_endpoint() {
    local url=$1
    local name=$2
    local expected_status=$3
    
    echo -n "Checking $name ($url)... "
    
    for i in $(seq 1 $RETRIES); do
        response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$url" 2>/dev/null || echo "000")
        
        if [ "$response" = "$expected_status" ]; then
            echo -e "${GREEN}✓${NC} (HTTP $response)"
            return 0
        elif [ "$response" = "000" ]; then
            echo -n "(connection failed, retry $i/$RETRIES)... "
            sleep 2
        else
            echo -e "${YELLOW}⚠${NC} (HTTP $response, expected $expected_status)"
            return 1
        fi
    done
    
    echo -e "${RED}✗${NC} (Failed after $RETRIES retries)"
    return 1
}

check_docker_health() {
    local service=$1
    local container_name=$2
    
    echo -n "Checking Docker health for $service... "
    
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    elif docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    else
        echo -e "${YELLOW}⚠${NC} (docker-compose not found, skipping)"
        return 0
    fi
    
    health=$($DOCKER_COMPOSE ps "$service" --format json 2>/dev/null | grep -o '"Health":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    
    if [ "$health" = "healthy" ]; then
        echo -e "${GREEN}✓${NC} (healthy)"
        return 0
    elif [ "$health" = "starting" ]; then
        echo -e "${YELLOW}⚠${NC} (starting)"
        return 1
    else
        echo -e "${RED}✗${NC} ($health)"
        return 1
    fi
}

# Main execution
echo "=========================================="
echo "LiteLLM Health Check"
echo "=========================================="
echo ""

# Check if containers are running
if ! docker ps | grep -q "litellm-admin\|litellm-api"; then
    echo -e "${RED}Error: No LiteLLM containers are running${NC}"
    exit 1
fi

FAILED=0

# Check Docker health status
echo "Docker Health Status:"
check_docker_health "litellm-admin" "litellm-admin" || FAILED=$((FAILED + 1))
check_docker_health "litellm-api" "litellm-api" || FAILED=$((FAILED + 1))
echo ""

# Check API endpoints
echo "Service Endpoints:"
check_endpoint "$API_URL/health" "API Health" "200" || FAILED=$((FAILED + 1))

# Admin UI might return 200 or redirect, so accept both
response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$ADMIN_URL/ui" 2>/dev/null || echo "000")
if [ "$response" = "200" ] || [ "$response" = "302" ] || [ "$response" = "301" ]; then
    echo -e "Checking Admin UI ($ADMIN_URL/ui)... ${GREEN}✓${NC} (HTTP $response)"
else
    echo -e "Checking Admin UI ($ADMIN_URL/ui)... ${RED}✗${NC} (HTTP $response)"
    FAILED=$((FAILED + 1))
fi

# Check if services are listening on correct ports
echo ""
echo "Port Status:"
if netstat -an 2>/dev/null | grep -q ":4000.*LISTEN" || lsof -i :4000 2>/dev/null | grep -q LISTEN; then
    echo -e "Port 4000 (API)... ${GREEN}✓${NC} (listening)"
else
    echo -e "Port 4000 (API)... ${YELLOW}⚠${NC} (not detected, may be normal on some systems)"
fi

if netstat -an 2>/dev/null | grep -q ":4001.*LISTEN" || lsof -i :4001 2>/dev/null | grep -q LISTEN; then
    echo -e "Port 4001 (Admin)... ${GREEN}✓${NC} (listening)"
else
    echo -e "Port 4001 (Admin)... ${YELLOW}⚠${NC} (not detected, may be normal on some systems)"
fi

# Final summary
echo ""
echo "=========================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All health checks passed!${NC}"
    exit 0
else
    echo -e "${RED}Health check failed ($FAILED issue(s))${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check container logs: docker-compose logs"
    echo "  2. Check container status: docker-compose ps"
    echo "  3. Restart services: docker-compose restart"
    exit 1
fi
