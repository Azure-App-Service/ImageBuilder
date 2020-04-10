#!/usr/bin/env bash

# Get environment variables to show up in SSH session
eval $(printenv | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/"/\\\"/g' | sed '/=/s//="/' | sed 's/$/"/' >> /etc/profile)

# starting sshd process
sed -i "s/SSH_PORT/$SSH_PORT/g" /etc/ssh/sshd_config
/usr/sbin/sshd

# check if $PORT exists, else set it to 8080
if [[ -z "${PORT}" ]]; then
    PORT="8080"
    export PORT="$PORT"
else
    PORT="${PORT}"
fi

# replace occurence of PORT in config site file for nginx
sed -i "s/PORT/$PORT/g" /etc/nginx/sites-available/mysite
ln -s /etc/nginx/sites-available/mysite /etc/nginx/sites-enabled/mysite
# nginx -g 'daemon off;'
echo "Restarting nginx..."
service nginx restart

exec "$@"


