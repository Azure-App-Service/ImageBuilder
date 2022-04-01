#Configure CDN settings 
wp w3-total-cache option set cdn.enabled true --type=boolean --path=$WORDPRESS_HOME --allow-root
wp w3-total-cache option set cdn.engine "mirror" --path=$WORDPRESS_HOME --allow-root
wp w3-total-cache option set cdn.mirror.domain $CDN_ENDPOINT --type=array --path=$WORDPRESS_HOME --allow-root

echo "CDN_CONFIGURATION_COMPLETE" >> $WORDPRESS_LOCK_FILE

#stop atd daemon
service atd stop
