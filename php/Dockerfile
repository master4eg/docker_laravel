FROM php:8.3-fpm-alpine

ARG PUID=1000
ARG PGID=1000

# Ставим системные пакеты и необходимые расширения PHP
RUN set -eux; \
    apk add --no-cache git curl unzip libzip-dev icu-dev oniguruma-dev shadow bash autoconf gcc g++ make; \
    docker-php-ext-install pdo_mysql intl mbstring opcache zip; \
    # Настраиваем пользователя www-data под UID/GID хоста
    groupmod -o -g ${PGID} www-data; \
    usermod  -o -u ${PUID} -g ${PGID} www-data; \
    # Composer
    curl -fsSL https://getcomposer.org/installer -o /tmp/composer-installer.php; \
    php /tmp/composer-installer.php --install-dir=/usr/local/bin --filename=composer; \
    rm -f /tmp/composer-installer.php; \
    mkdir -p /var/www/.composer && chown -R www-data:www-data /var/www

COPY php.ini /usr/local/etc/php/conf.d/zz-custom.ini

WORKDIR /var/www/html

USER www-data

CMD ["php-fpm"]