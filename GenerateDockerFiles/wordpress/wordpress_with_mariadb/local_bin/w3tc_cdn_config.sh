#Configure CDN settings 
wp w3-total-cache option set cdn.enabled $CDN_ENABLED --path=$WORDPRESS_HOME --allow-root
wp w3-total-cache option set cdn.engine "mirror" --path=$WORDPRESS_HOME --allow-root
wp w3-total-cache option set cdn.mirror.domain ["$CDN_ENDPOINT"] --path=$WORDPRESS_HOME --allow-root

echo "CDN_CONFIGURATION_COMPLETE" >> $WORDPRESS_LOCK_FILE

#stop atd daemon
service atd stop
