#!/bin/sh
set -e
mkdir -p /root/.cache/crontab
CRON_JOB="* * * * * /usr/local/bin/php /var/www/html/think cronJob > /dev/null 2>&1"
geo_check() {
    api_list="https://cloudflare.com/cdn-cgi/trace https://blog.cloudflare.com/cdn-cgi/trace https://dash.cloudflare.com/cdn-cgi/trace https://developers.cloudflare.com/cdn-cgi/trace"
    ua="Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/81.0"
    isCN="false"
    for url in $api_list; do
        text="$(curl -A "$ua" -m 10 -sSL "$url" 2>/dev/null)" || continue
        [ -z "$text" ] && continue
        location="$(echo "$text" | grep '^loc=' | cut -d'=' -f2)"
        if [ -n "$location" ]; then
            if [ "$location" = "CN" ]; then
                isCN="true"
            else
                isCN="false"
            fi
            break
        else
            if echo "$text" | grep -q 'loc=CN'; then
                isCN="true"
                break
            fi
        fi
    done
}
geo_check
cd /var/www/html || exit 1
if [ "$isCN" = "true" ]; then
    echo "使用国内镜像"
    composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/
fi
composer upgrade --no-interaction --optimize-autoloader
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
php think migrate:run
php think clear
if ! crontab -l 2>/dev/null | grep -Fq "$CRON_JOB"; then
    ( crontab -l 2>/dev/null; echo "$CRON_JOB" ) | crontab -
fi
crond -f &
exec "$@"
