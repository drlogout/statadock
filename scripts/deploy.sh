#!/bin/bash

# Set PHP version

cd /var/www/html || exit 1

# Only pull if git access is available
if git ls-remote --heads origin "$SITE_BRANCH" >/dev/null 2>&1; then
    /usr/bin/git pull origin "$SITE_BRANCH"
fi

/usr/bin/composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev

/var/www/.volta/bin/volta run --node "$NODE_VERSION" npm ci
/var/www/.volta/bin/volta run --node "$NODE_VERSION" npm run build

( flock -w 10 9 || exit 1
    echo 'Restarting FPM...'; kill -USR2 $(pgrep -f "php-fpm${PHP_VERSION}") ) 9>/tmp/fpmlock

# Generate APP_KEY
if ! grep -q "APP_KEY=base64:" "/var/www/html/.env"; then
    /usr/bin/php artisan key:generate
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
