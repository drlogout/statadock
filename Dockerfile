FROM ubuntu:22.04

ARG PHP_VERSION
ENV PHP_VERSION=${PHP_VERSION}

# Set timezone to UTC
ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt update --fix-missing && \
    apt install -y software-properties-common && \
    add-apt-repository ppa:ondrej/php && \
    apt install -y \
        nginx \
        php${PHP_VERSION} \
        php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-dev \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-gmp \
        php${PHP_VERSION}-igbinary \
        php${PHP_VERSION}-imagick \
        php${PHP_VERSION}-imap \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-memcached \
        php${PHP_VERSION}-msgpack \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-opcache \
        php${PHP_VERSION}-pgsql \
        php${PHP_VERSION}-readline \
        php${PHP_VERSION}-redis \
        php${PHP_VERSION}-soap \
        php${PHP_VERSION}-sqlite3 \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-zip \
        rsync \
        unzip \
        vim \
        zip && \
    rm -rf /var/lib/apt/lists/* && \
    apt clean

# PHP config
COPY php/fpm/php.ini /etc/php/${PHP_VERSION}/fpm/php.ini
COPY php/fpm/php${PHP_VERSION}-fpm.conf /etc/php/${PHP_VERSION}/fpm/php-fpm.conf
COPY php/fpm/pool.d/www.conf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
RUN mkdir -p /var/run/php

# Nginx config
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/fastcgi_params /etc/nginx/fastcgi_params
COPY nginx/mime.types /etc/nginx/mime.types
COPY nginx/conf.d/ /etc/nginx/conf.d/
COPY nginx/sites-enabled/www.conf /etc/nginx/sites-enabled/www.conf

# Composer & Statamic CLI
COPY --from=composer:2.5 /usr/bin/composer /usr/bin/composer
RUN echo "PATH=/root/.config/composer/vendor/bin:$PATH" >> /root/.bashrc
RUN composer global require statamic/cli

# Scripts
COPY scripts/statamic.sh /usr/local/bin/statamic
COPY scripts/install-statamic.sh /usr/local/bin/install-statamic
COPY scripts/install-peak.sh /usr/local/bin/install-peak

COPY index.php /var/www/html/public/index.php

EXPOSE 80

WORKDIR /var/www/html

STOPSIGNAL SIGTERM

# Start PHP-FPM and Nginx
CMD ["/bin/bash", "-c", "php-fpm${PHP_VERSION} -R && nginx -g 'daemon off;'"]

