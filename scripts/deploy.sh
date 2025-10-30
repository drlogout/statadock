#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Logging functions
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_warning() {
    echo "[WARNING] $1"
}

# Default values
SSH_KEY=/root/.ssh/id_rsa
BRANCH="main"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--branch)
            BRANCH="$2"
            shift 2
            ;;
        -k|--ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 -b <branch> [-k <ssh-key>]"
            echo ""
            echo "Options:"
            echo "  -b, --branch <branch>     Branch name to checkout (required)"
            echo "  -k, --ssh-key <path>      Path to SSH key (default: /root/.ssh/id_rsa)"
            echo "  -h, --help                Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            log_error "Usage: $0 -b <branch> [-k <ssh-key>]"
            exit 1
            ;;
    esac
done

# Trim whitespace from branch
BRANCH=$(echo "$BRANCH" | xargs)

# Validate required parameters
if [ -z "$BRANCH" ]; then
    log_error "Error: Branch parameter is required"
    log_error "Usage: $0 -b <branch> [-k <ssh-key>]"
    exit 1
fi

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    log_error "Error: SSH key not found at $SSH_KEY"
    exit 1
fi

cd /var/www/html || exit 1

# Configure git to trust the repository directory (local config to avoid permission issues)
/usr/bin/git config --local --add safe.directory /var/www/html

# Configure git pull strategy to avoid divergent branches error (local config)
/usr/bin/git config --local pull.rebase false

export GIT_SSH_COMMAND="ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

log_info "Processing branch: $BRANCH"

# Fetch from remote to get latest branch information
log_info "Fetching from remote..."
if ! /usr/bin/git fetch origin '+refs/heads/*:refs/remotes/origin/*'; then
    log_error "Error: Failed to fetch from remote"
    exit 1
fi

# Clean working directory before switching branches
# This ensures we can switch branches even if there are local changes
log_info "Cleaning working directory (discarding any local changes)..."
/usr/bin/git reset --hard HEAD || { log_error "Failed to reset working directory"; exit 1; }
/usr/bin/git clean -fd || { log_error "Failed to clean working directory"; exit 1; }

# Check if branch exists locally
if /usr/bin/git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    log_info "Branch $BRANCH exists locally, switching to it"
    if ! /usr/bin/git checkout "$BRANCH"; then
        log_error "Failed to checkout branch $BRANCH"
        exit 1
    fi
# Check if branch exists remotely
elif /usr/bin/git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    log_info "Branch $BRANCH exists remotely, creating local tracking branch"
    if ! /usr/bin/git checkout -b "$BRANCH" "origin/$BRANCH"; then
        log_error "Failed to create and checkout branch $BRANCH"
        exit 1
    fi
else
    log_error "Error: Branch $BRANCH not found locally or remotely"
    exit 1
fi

# Force local branch to match remote exactly (discard any local commits)
log_info "Syncing local branch with remote (discarding local changes)..."
if ! /usr/bin/git reset --hard "origin/$BRANCH"; then
    log_error "Error: Could not reset to origin/$BRANCH"
    exit 1
fi

log_info "Local branch now matches remote origin/$BRANCH"

# Clear Laravel caches before composer install to prevent stale cache issues
rm -rf bootstrap/cache/*.php

log_info "Installing Composer dependencies..."
if ! /usr/bin/composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev --no-progress; then
    log_error "Failed to install Composer dependencies"
    exit 1
fi

log_info "Installing NPM dependencies..."
if ! CI=true npm_config_yes=true /var/www/.volta/bin/volta run --node "$NODE_VERSION" npm ci --no-audit --no-progress --prefer-offline; then
    log_error "Failed to install NPM dependencies"
    exit 1
fi

log_info "Building assets..."
if ! CI=true npm_config_yes=true /var/www/.volta/bin/volta run --node "$NODE_VERSION" npm run build --no-progress --prefer-offline; then
    log_error "Failed to build assets"
    exit 1
fi

log_info "Restarting PHP-FPM..."
( flock -w 10 9 || exit 1
    FPM_PID=$(pgrep -f "php-fpm${PHP_VERSION}" | head -n 1)
    if [ -n "$FPM_PID" ]; then
        kill -USR2 "$FPM_PID" && echo "FPM restarted successfully"
    else
        echo "Warning: PHP-FPM process not found, skipping restart"
    fi
) 9>/tmp/fpmlock

# Generate APP_KEY
if ! grep -q "APP_KEY=[\"']\?base64:" "/var/www/html/.env"; then
    log_info "Generating APP_KEY..."
    if ! /usr/bin/php artisan key:generate --force; then
        log_error "Failed to generate APP_KEY"
        exit 1
    fi
fi

log_info "Clearing Laravel caches..."
if ! /usr/bin/php artisan cache:clear; then
    log_error "Failed to clear cache"
    exit 1
fi

if ! /usr/bin/php artisan optimize:clear; then
    log_error "Failed to clear optimized files"
    exit 1
fi

if ! /usr/bin/php artisan config:cache; then
    log_error "Failed to cache configuration"
    exit 1
fi

if ! /usr/bin/php artisan route:cache; then
    log_error "Failed to cache routes"
    exit 1
fi

# Restart horizon
if /usr/bin/php artisan horizon:status >/dev/null 2>&1; then
    log_info "Terminating Horizon..."
    if ! /usr/bin/php artisan horizon:terminate; then
        log_warning "Failed to terminate Horizon (non-critical)"
    fi
fi

# Reverb
if [ "${RESTART_REVERB:-false}" = "true" ]; then
    log_info "Restarting Reverb..."
    if ! /usr/bin/php artisan reverb:restart; then
        log_warning "Failed to restart Reverb (non-critical)"
    fi
fi

# Static cache:
if [ "${UPDATE_STATIC_CACHE:-false}" = "true" ]; then
    log_info "Updating static cache..."
    if ! /usr/bin/php artisan statamic:static:clear; then
        log_error "Failed to clear static cache"
        exit 1
    fi
    if ! /usr/bin/php artisan statamic:static:warm --queue; then
        log_error "Failed to warm static cache"
        exit 1
    fi
fi

# Search
if [ "${UPDATE_SEARCH:-false}" = "true" ]; then
    log_info "Updating search index..."
    if ! /usr/bin/php artisan statamic:stache:warm; then
        log_error "Failed to warm stache"
        exit 1
    fi
    if ! /usr/bin/php artisan statamic:search:update --all; then
        log_error "Failed to update search index"
        exit 1
    fi
fi

# otherwise we get this error:
# [2025-10-07 17:04:29] staging.ERROR: Call to undefined method Statamic\Sites\Site::__set_state() {"exception":"[object] (Error(code: 0): Call to undefined method Statamic\\Sites\\Site::__set_state() at /var/www/html/bootstrap/cache/routes-v7.php:10537)
# [stacktrace]
rm -f bootstrap/cache/routes-v7.php

log_info "Deployment completed successfully!"
