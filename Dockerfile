FROM php:8.1-fpm

# Arguments defined in docker-compose.yml
ARG user
ARG uid

# Set working directory
WORKDIR /var/www

# Add docker php ext repo
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

# Install php extensions
RUN chmod +x /usr/local/bin/install-php-extensions && sync && \
    install-php-extensions mbstring pdo_mysql zip exif pcntl gd memcached

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    nano \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    locales \
    zip \
    jpegoptim optipng pngquant gifsicle \
    unzip \
    git \
    curl \
    lua-zlib-dev \
    libmemcached-dev \
    cron

# Install supervisor
RUN apt-get install -y supervisor

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Add user for laravel application
RUN groupadd -g $uid $user
RUN useradd -ms /bin/bash $user -g $user

# Copy code to /var/www
COPY --chown=$user:$user . /var/www

# add root to www group
RUN chmod -R ug+w /var/www/storage

# Copy php/supervisor configs
RUN cp docker/supervisord.conf /etc/supervisor/conf.d
RUN cp docker/php.ini /usr/local/etc/php/conf.d/app.ini

# PHP Error Log Files
RUN mkdir /var/log/php

# Deployment steps
RUN composer install --optimize-autoloader --no-dev
RUN chmod +x /var/www/docker/entrypoint.sh

COPY docker/cron /etc/cron.d/scheduler
RUN chmod 0644 /etc/cron.d/scheduler \
    && crontab /etc/cron.d/scheduler

EXPOSE 9000
ENTRYPOINT ["sh","/var/www/docker/entrypoint.sh"]
