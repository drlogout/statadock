FROM ubuntu:24.04

ARG PHP_VERSION=8.3
ARG NODE_VERSION=22.14
ENV PHP_VERSION=${PHP_VERSION}
ENV NODE_VERSION=${NODE_VERSION}

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# Set timezone to UTC
ENV TZ=Europe/Berlin
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt update --fix-missing && \
    apt install -y software-properties-common && \
    add-apt-repository ppa:ondrej/php && \
    apt install -y \
    chromium \
    chromium-driver \
    git \
    gosu \
    nginx \
    pcregrep \
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
    jq \
    sudo \
    rsync \
    unzip \
    vim \
    zip && \
    rm -rf /var/lib/apt/lists/* && \
    apt clean

RUN echo www-data ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/www-data \
    && chmod 0440 /etc/sudoers.d/www-data

# PHP config
COPY php/fpm/php.ini /etc/php/${PHP_VERSION}/fpm/php.ini
COPY php/fpm/php-fpm.conf /etc/php/${PHP_VERSION}/fpm/php-fpm.conf
COPY php/fpm/pool.d/www.conf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf
RUN mkdir -p /var/run/php

# Nginx config
RUN rm -f /etc/nginx/sites-enabled/* && rm -f /etc/nginx/sites-available/*
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/sites-available/ /etc/nginx/sites-available/
COPY nginx/fastcgi_params /etc/nginx/fastcgi_params
COPY nginx/mime.types /etc/nginx/mime.types
COPY nginx/conf.d/ /etc/nginx/conf.d/

# Composer & Statamic CLI
COPY --from=composer:2.5 /usr/bin/composer /usr/bin/composer
RUN echo "PATH=/root/.config/composer/vendor/bin:$PATH" >> /root/.bashrc
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_PROCESS_TIMEOUT=600
RUN composer global require statamic/cli --no-plugins --no-scripts --prefer-dist

# Scripts
COPY scripts/statamic.sh /usr/local/bin/statamic
COPY scripts/install-statamic.sh /usr/local/bin/install-statamic
COPY scripts/install-peak.sh /usr/local/bin/install-peak
COPY scripts/deploy.sh /usr/local/bin/deploy
COPY scripts/clear-cache.sh /usr/local/bin/clear-cache

COPY index.php /var/www/html/public/index.php

EXPOSE 80

WORKDIR /var/www/html

RUN chown -R www-data:www-data /var/www
RUN mkdir -p /run/php/
RUN touch /run/php/php-fpm.sock
RUN chown -R www-data:www-data /run/php/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN echo www-data ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/www-data \
    && chmod 0440 /etc/sudoers.d/www-data

USER www-data

RUN curl https://get.volta.sh | bash && \
    /var/www/.volta/bin/volta install node@$NODE_VERSION

# Switch back to root for entrypoint to handle user/group setup
USER root

ENTRYPOINT [ "/entrypoint.sh" ]
