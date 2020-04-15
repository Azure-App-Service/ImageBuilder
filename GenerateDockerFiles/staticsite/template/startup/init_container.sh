#!/usr/bin/env bash

# Get environment variables to show up in SSH session
eval $(printenv | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/"/\\\"/g' | sed '/=/s//="/' | sed 's/$/"/' >> /etc/profile)

# starting sshd process
sed -i "s/SSH_PORT/$SSH_PORT/g" /etc/ssh/sshd_config
/usr/sbin/sshd

# replace occurence of PORT in config site file for nginx
sed -i "s/PORT/$PORT/g" /etc/nginx/sites-available/mysite
ln -s /etc/nginx/sites-available/mysite /etc/nginx/sites-enabled/mysite

echo "Restarting nginx..."
service nginx restart

exec "$@"


