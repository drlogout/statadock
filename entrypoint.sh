#!/bin/sh

# Check if REVERSE_PROXY is set to true
if [ "$REVERSE_PROXY" = "true" ]; then
    echo "Using reverse proxy configuration..."
    sudo ln -s /etc/nginx/sites-available/default.reverse-proxy.conf /etc/nginx/sites-enabled/default
else
    echo "Using standard configuration..."
    sudo ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default
fi

# Start PHP-FPM in the background
php-fpm${PHP_VERSION} -R &

# Start nginx in the foreground with sudo
exec sudo nginx -g 'daemon off;' 
