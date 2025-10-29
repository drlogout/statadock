#!/bin/bash

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

# Configure git to trust the repository directory
/usr/bin/git config --global --add safe.directory /var/www/html

export GIT_SSH_COMMAND="ssh -i $SSH_KEY -o StrictHostKeyChecking=no"

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
/usr/bin/git reset --hard HEAD
/usr/bin/git clean -fd

# Check if branch exists locally
if /usr/bin/git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    log_info "Branch $BRANCH exists locally, switching to it"
    /usr/bin/git checkout "$BRANCH"
# Check if branch exists remotely
elif /usr/bin/git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    log_info "Branch $BRANCH exists remotely, creating local tracking branch"
    /usr/bin/git checkout -b "$BRANCH" "origin/$BRANCH"
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

/usr/bin/composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev

CI=true npm_config_yes=true /var/www/.volta/bin/volta run --node "$NODE_VERSION" npm ci --no-audit --no-progress --prefer-offline
CI=true npm_config_yes=true /var/www/.volta/bin/volta run --node "$NODE_VERSION" npm run build --no-progress --prefer-offline

( flock -w 10 9 || exit 1
    echo 'Restarting FPM...'; kill -USR2 $(pgrep -f "php-fpm${PHP_VERSION}") ) 9>/tmp/fpmlock

# Generate APP_KEY
if ! grep -q "APP_KEY=[\"']\?base64:" "/var/www/html/.env"; then
    /usr/bin/php artisan key:generate --force
fi

/usr/bin/php artisan cache:clear
/usr/bin/php artisan optimize:clear
/usr/bin/php artisan config:cache # Caches all configuration files (e.g. .env)
/usr/bin/php artisan route:cache

# Restart horizon
if /usr/bin/php artisan horizon:status >/dev/null 2>&1; then
    /usr/bin/php artisan horizon:terminate
fi

# Reverb
if [ "$RESTART_REVERB" = "true" ]; then
    /usr/bin/php artisan reverb:restart
fi

# Static cache:
if [ "$UPDATE_STATIC_CACHE" = "true" ]; then
    /usr/bin/php artisan statamic:static:clear
    /usr/bin/php artisan statamic:static:warm --queue
fi

# Search
if [ "$UPDATE_SEARCH" = "true" ]; then
    /usr/bin/php artisan statamic:stache:warm
    /usr/bin/php artisan statamic:search:update --all
fi

# otherwise we get this error:
# [2025-10-07 17:04:29] staging.ERROR: Call to undefined method Statamic\Sites\Site::__set_state() {"exception":"[object] (Error(code: 0): Call to undefined method Statamic\\Sites\\Site::__set_state() at /var/www/html/bootstrap/cache/routes-v7.php:10537)
# [stacktrace]
rm bootstrap/cache/routes-v7.php
