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

log_info "Running 'rm -rf bootstrap/cache/*.php'"
rm -rf bootstrap/cache/*.php

log_info "Running 'artisan cache:clear'"
if ! /usr/bin/php artisan cache:clear; then
    log_error "artisan cache:clear failed"
fi

log_info "Running 'artisan optimize:clear'"
if ! /usr/bin/php artisan optimize:clear; then
    log_error "optimized:clear failed"
fi

log_info "Running 'artisan config:cache'"
if ! /usr/bin/php artisan config:cache; then
    log_error "config:cache failed"
fi

log_info "Running 'artisan route:cache'"
if ! /usr/bin/php artisan route:cache; then
    log_error "route:cache failed"
fi

# Static cache
if [ "${UPDATE_STATIC_CACHE:-false}" = "true" ]; then
    log_info "Updating static cache..."
    if ! /usr/bin/php artisan statamic:static:clear; then
        log_error "Failed to clear static cache"
    fi
    if ! /usr/bin/php artisan statamic:static:warm --queue; then
        log_error "Failed to warm static cache"
    fi
fi

# Search
if [ "${UPDATE_SEARCH:-false}" = "true" ]; then
    log_info "Updating search index..."
    if ! /usr/bin/php artisan statamic:stache:warm; then
        log_error "Failed to warm stache"
    fi
    if ! /usr/bin/php artisan statamic:search:update --all; then
        log_error "Failed to update search index"
    fi
fi

# Clean up routes cache file to prevent Site::__set_state() error
log_info "Running 'rm -f bootstrap/cache/routes-v7.php'"
rm -f bootstrap/cache/routes-v7.php
