#!/bin/sh

# Modify www-data UID/GID if USER_ID and GROUP_ID are provided
if [ -n "${USER_ID:-}" ] && [ -n "${GROUP_ID:-}" ]; then
    echo "Adjusting www-data UID to $USER_ID and GID to $GROUP_ID..."
    
    # Get current www-data UID and GID
    CURRENT_UID=$(id -u www-data)
    CURRENT_GID=$(id -g www-data)
    
    # Only modify if different from current values
    if [ "$CURRENT_GID" != "$GROUP_ID" ]; then
        groupmod -o -g $GROUP_ID www-data
    fi
    
    if [ "$CURRENT_UID" != "$USER_ID" ]; then
        usermod -o -u $USER_ID www-data
    fi
    
    # Update ownership of directories
    chown -R www-data:www-data /var/www /run/php

    log_info "Starting PHP-FPM in the background as www-data..."
    gosu www-data php-fpm${PHP_VERSION} -F &
else
    log_info "Starting PHP-FPM in the background as root..."
    php-fpm${PHP_VERSION} -F &
fi

# Check if REVERSE_PROXY is set to true
if [ "$REVERSE_PROXY" = "true" ]; then
    echo "Using reverse proxy configuration..."
    ln -sf /etc/nginx/sites-available/default.reverse-proxy.conf /etc/nginx/sites-enabled/default
else
    echo "Using standard configuration..."
    ln -sf /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default
fi

# Start nginx in foreground (runs as root, worker processes as www-data)
exec nginx -g 'daemon off;' 
