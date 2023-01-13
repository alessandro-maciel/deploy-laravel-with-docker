#!/bin/sh

cd /var/www

# php artisan migrate:fresh --seed
php artisan cache:clear
php artisan route:cache

/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
