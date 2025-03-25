#!/bin/sh

# Check if REVERSE_PROXY is set to true
if [ "$REVERSE_PROXY" = "true" ]; then
    echo "Using reverse proxy configuration..."
    sudo cp /etc/nginx/docker-conf/default.rp.conf /etc/nginx/sites-enabled/default
    sudo cp /etc/nginx/docker-conf/nginx.rp.conf /etc/nginx/nginx.conf
else
    echo "Using standard configuration..."
    sudo cp /etc/nginx/docker-conf/default.conf /etc/nginx/sites-enabled/default
    sudo cp /etc/nginx/docker-conf/nginx.conf /etc/nginx/nginx.conf
fi

# Start PHP-FPM in the background
php-fpm${PHP_VERSION} -R &

# Start nginx in the foreground with sudo
exec sudo nginx -g 'daemon off;' 
