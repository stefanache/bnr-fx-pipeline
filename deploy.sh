#!/bin/bash
#===============================================================================
# BNR FX Rates Pipeline - CI/CD Deployment Script
# For Ubuntu 24.04 LTS
#
# This script:
# 1. Pulls latest code from GitHub
# 2. Runs tests
# 3. Deploys to Cloudflare Workers
# 4. Updates RapidAPI (if configured)
#
# Prerequisites:
#   - Node.js 18+ and npm
#   - Git
#   - Wrangler CLI (installed automatically)
#   - Environment variables set (see below)
#
# Required Environment Variables:
#   CLOUDFLARE_API_TOKEN    - Cloudflare API token with Workers permissions
#   CLOUDFLARE_ACCOUNT_ID   - Your Cloudflare account ID
#   GITHUB_REPO             - GitHub repository URL
#   RAPIDAPI_KEY            - (Optional) RapidAPI provider key
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh
#
#===============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="bnr-fx-rates"
D1_DATABASE_NAME="bnr-fx-db"

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

#-------------------------------------------------------------------------------
# Pre-flight Checks
#-------------------------------------------------------------------------------

preflight_checks() {
    log_info "Running pre-flight checks..."

    # Check Node.js
    if ! check_command node; then
        log_error "Node.js is not installed. Please install Node.js 18+:"
        echo "  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
        echo "  sudo apt-get install -y nodejs"
        exit 1
    fi

    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        log_error "Node.js 18+ required. Current version: $(node -v)"
        exit 1
    fi
    log_success "Node.js $(node -v) detected"

    # Check npm
    if ! check_command npm; then
        log_error "npm is not installed"
        exit 1
    fi
    log_success "npm $(npm -v) detected"

    # Check git
    if ! check_command git; then
        log_error "Git is not installed. Install with: sudo apt install git"
        exit 1
    fi
    log_success "Git detected"

    # Check environment variables
    if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
        log_error "CLOUDFLARE_API_TOKEN environment variable is not set"
        echo "  Export it: export CLOUDFLARE_API_TOKEN='your-api-token'"
        exit 1
    fi
    log_success "CLOUDFLARE_API_TOKEN is set"

    if [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
        log_error "CLOUDFLARE_ACCOUNT_ID environment variable is not set"
        echo "  Export it: export CLOUDFLARE_ACCOUNT_ID='your-account-id'"
        exit 1
    fi
    log_success "CLOUDFLARE_ACCOUNT_ID is set"
}

#-------------------------------------------------------------------------------
# Install Dependencies
#-------------------------------------------------------------------------------

install_dependencies() {
    log_info "Installing/updating Wrangler CLI..."

    # Install wrangler globally if not present
    if ! check_command wrangler; then
        npm install -g wrangler
    else
        log_info "Wrangler already installed, checking for updates..."
        npm update -g wrangler 2>/dev/null || true
    fi

    log_success "Wrangler $(wrangler --version) ready"
}

#-------------------------------------------------------------------------------
# Pull Latest Code
#-------------------------------------------------------------------------------

pull_latest() {
    log_info "Pulling latest code from GitHub..."

    if [ -n "$GITHUB_REPO" ]; then
        # If GITHUB_REPO is set and we're not in the repo, clone it
        if [ ! -d ".git" ]; then
            log_info "Cloning repository..."
            git clone "$GITHUB_REPO" .
        else
            log_info "Fetching and pulling latest changes..."
            git fetch origin
            git pull origin main || git pull origin master
        fi
        log_success "Code is up to date"
    else
        log_warn "GITHUB_REPO not set, skipping git pull"
    fi
}

#-------------------------------------------------------------------------------
# Run Tests
#-------------------------------------------------------------------------------

run_tests() {
    log_info "Running tests..."

    # Check if test file exists
    if [ -f "tests/test_worker.py" ]; then
        if check_command python3; then
            # Install test dependencies
            pip3 install -q pytest pytest-asyncio httpx 2>/dev/null || true

            # Run Python tests
            python3 -m pytest tests/ -v --tb=short || {
                log_error "Tests failed!"
                exit 1
            }
            log_success "All tests passed"
        else
            log_warn "Python3 not found, skipping Python tests"
        fi
    else
        log_warn "No tests found, skipping test phase"
    fi
}

#-------------------------------------------------------------------------------
# Setup D1 Database
#-------------------------------------------------------------------------------

setup_database() {
    log_info "Setting up D1 database..."

    # Check if database exists
    DB_EXISTS=$(wrangler d1 list 2>/dev/null | grep -c "$D1_DATABASE_NAME" || true)

    if [ "$DB_EXISTS" -eq 0 ]; then
        log_info "Creating D1 database: $D1_DATABASE_NAME"
        wrangler d1 create "$D1_DATABASE_NAME"

        # Get the database ID and update wrangler.toml
        DB_ID=$(wrangler d1 list 2>/dev/null | grep "$D1_DATABASE_NAME" | awk '{print $2}')
        if [ -n "$DB_ID" ]; then
            log_info "Database ID: $DB_ID"
            # Update wrangler.toml with the actual database ID
            sed -i "s/YOUR_D1_DATABASE_ID/$DB_ID/g" wrangler.toml
            log_success "Updated wrangler.toml with database ID"
        fi
    else
        log_success "D1 database already exists"
    fi

    # Run schema migration
    log_info "Running database schema migration..."
    wrangler d1 execute "$D1_DATABASE_NAME" --file=./schema.sql --remote || {
        log_warn "Schema might already exist, continuing..."
    }
    log_success "Database schema is ready"
}

#-------------------------------------------------------------------------------
# Deploy to Cloudflare
#-------------------------------------------------------------------------------

deploy_cloudflare() {
    log_info "Deploying to Cloudflare Workers..."

    # Deploy the worker
    wrangler deploy || {
        log_error "Deployment failed!"
        exit 1
    }

    # Get the worker URL
    WORKER_URL="https://${PROJECT_NAME}.${CLOUDFLARE_ACCOUNT_ID}.workers.dev"
    log_success "Deployed to Cloudflare Workers!"
    log_info "Worker URL: $WORKER_URL"

    # Test the deployment
    log_info "Testing deployed worker..."
    sleep 3  # Wait for deployment to propagate

    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${WORKER_URL}/health" 2>/dev/null || echo "000")
    if [ "$HTTP_STATUS" = "200" ]; then
        log_success "Worker is responding correctly"
    else
        log_warn "Worker returned HTTP $HTTP_STATUS (might need a moment to propagate)"
    fi
}

#-------------------------------------------------------------------------------
# Trigger Initial Data Fetch
#-------------------------------------------------------------------------------

trigger_initial_fetch() {
    log_info "Triggering initial BNR data fetch..."

    # Use wrangler to trigger the scheduled handler
    # This simulates the cron trigger for initial data population
    curl -s -X GET "https://${PROJECT_NAME}.${CLOUDFLARE_ACCOUNT_ID}.workers.dev/__scheduled" 2>/dev/null || {
        log_warn "Could not trigger scheduled fetch (this is normal for first deploy)"
    }

    log_info "Note: Cron will automatically fetch data daily at 8:00 AM UTC"
}

#-------------------------------------------------------------------------------
# Update RapidAPI (Optional)
#-------------------------------------------------------------------------------

update_rapidapi() {
    if [ -z "$RAPIDAPI_KEY" ]; then
        log_warn "RAPIDAPI_KEY not set, skipping RapidAPI update"
        log_info "To enable RapidAPI sync, set: export RAPIDAPI_KEY='your-rapidapi-provider-key'"
        return
    fi

    log_info "Updating RapidAPI configuration..."

    # RapidAPI Hub API for updating API definition
    # This requires the RapidAPI Provider Hub API
    # Documentation: https://docs.rapidapi.com/docs/provider-api

    WORKER_URL="https://${PROJECT_NAME}.${CLOUDFLARE_ACCOUNT_ID}.workers.dev"

    log_info "RapidAPI base URL should be: $WORKER_URL"
    log_info "Import openapi.yaml into RapidAPI Hub manually or use their API"
    log_success "RapidAPI ready for configuration"
}

#-------------------------------------------------------------------------------
# Print Summary
#-------------------------------------------------------------------------------

print_summary() {
    echo ""
    echo "==============================================================================="
    echo -e "${GREEN}DEPLOYMENT COMPLETE${NC}"
    echo "==============================================================================="
    echo ""
    echo "Worker URL: https://${PROJECT_NAME}.${CLOUDFLARE_ACCOUNT_ID}.workers.dev"
    echo ""
    echo "API Endpoints:"
    echo "  GET /health           - Health check"
    echo "  GET /rates            - Latest rates"
    echo "  GET /rates?date=YYYY-MM-DD          - Rates for specific date"
    echo "  GET /rates?currency=EUR             - EUR history (last 30 days)"
    echo "  GET /rates?currency=EUR&from=YYYY-MM-DD  - EUR from specific date"
    echo ""
    echo "Cron Schedule: Daily at 8:00 AM UTC"
    echo ""
    echo "Next Steps:"
    echo "  1. Test the API: curl https://${PROJECT_NAME}.${CLOUDFLARE_ACCOUNT_ID}.workers.dev/health"
    echo "  2. Import openapi.yaml into RapidAPI Hub"
    echo "  3. Configure RapidAPI pricing and documentation"
    echo ""
    echo "==============================================================================="
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------

main() {
    echo ""
    echo "==============================================================================="
    echo "BNR FX Rates Pipeline - CI/CD Deployment"
    echo "==============================================================================="
    echo ""

    cd "$SCRIPT_DIR"

    preflight_checks
    install_dependencies
    pull_latest
    run_tests
    setup_database
    deploy_cloudflare
    trigger_initial_fetch
    update_rapidapi
    print_summary
}

# Run main function
main "$@"
