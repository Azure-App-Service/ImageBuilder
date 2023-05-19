cdn_type="$1"

afd_update_site_url() {
    	afd_url="\$http_protocol . \$_SERVER['HTTP_HOST']"
    	if [[ $AFD_ENABLED ]]; then
    	    if [[ $AFD_CUSTOM_DOMAIN ]]; then
    	        afd_url="\$http_protocol . '$AFD_CUSTOM_DOMAIN'"
    	    elif [[ $AFD_ENDPOINT ]]; then
    	        afd_url="\$http_protocol . '$AFD_ENDPOINT'"
    	    fi
    	fi
   
        if wp config set WP_HOME "$afd_url" --raw --path=$WORDPRESS_HOME --allow-root \
    	&& wp config set WP_SITEURL "$afd_url" --raw --path=$WORDPRESS_HOME --allow-root; then
    	    echo "${cdn_type}_CONFIGURATION_COMPLETE" >> $WORDPRESS_LOCK_FILE
    	fi 

        AFD_URL="\$http_protocol . \$_SERVER['HTTP_HOST']"
        if [[ $AFD_CUSTOM_DOMAIN ]]; then
            AFD_URL="\$http_protocol . '$AFD_CUSTOM_DOMAIN'"
        elif [[ $AFD_ENDPOINT ]]; then
            AFD_URL="\$http_protocol . '$AFD_ENDPOINT'"
        fi

        wp config set WP_HOME "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_HOME --allow-root
        wp config set WP_SITEURL "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_HOME --allow-root
        wp option update siteurl "https://$AFD_URL" --path=$WORDPRESS_HOME --allow-root
        wp option update home "https://$AFD_URL" --path=$WORDPRESS_HOME --allow-root

        if [ -e "$WORDPRESS_HOME/wp-config.php" ]; then
            XFORWARD_HEADER_DETECTED=$(grep "\$_SERVER\['HTTP_HOST'\]=\$_SERVER\['HTTP_X_FORWARDED_HOST'\];" $WORDPRESS_HOME/wp-config.php)
            if [ ! $XFORWARD_HEADER_DETECTED ];then
                sed -i "/Using environment variables for memory limits/e cat $WORDPRESS_SOURCE/afd-header-settings.txt" $WORDPRESS_HOME/wp-config.php
            fi
        fi

        echo "${cdn_type}_CONFIGURATION_COMPLETE" >> $WORDPRESS_LOCK_FILE
}

#Configure CDN settings 
if [[ "$cdn_type" == "BLOB_CDN" ]] && [[ $CDN_ENDPOINT ]] && [ ! $(grep "BLOB_CDN_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] \
&& [[ $(curl --write-out '%{http_code}' --silent --output /dev/null {https://$CDN_ENDPOINT}) == "200" ]] \
&& wp plugin activate w3-total-cache --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set cdn.azure.cname $CDN_ENDPOINT --type=array --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set cdn.includes.enable true --type=boolean --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set cdn.theme.enable true --type=boolean --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set cdn.custom.enable true --type=boolean --path=$WORDPRESS_HOME --allow-root; then
    echo "BLOB_CDN_CONFIGURATION_COMPLETE" >> $WORDPRESS_LOCK_FILE
    service atd stop
    redis-cli flushall
elif [[ "$cdn_type" == "CDN" ]] && [[ $CDN_ENDPOINT ]] && [ ! $(grep "CDN_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] \
&& [[ $(curl --write-out '%{http_code}' --silent --output /dev/null {https://$CDN_ENDPOINT}) == "200" ]] \
&& wp plugin activate w3-total-cache --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set cdn.enabled true --type=boolean --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set cdn.engine "mirror" --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set cdn.mirror.domain $CDN_ENDPOINT --type=array --path=$WORDPRESS_HOME --allow-root; then
    echo "CDN_CONFIGURATION_COMPLETE" >> $WORDPRESS_LOCK_FILE
    service atd stop
    redis-cli flushall
elif [[ "$cdn_type" == "BLOB_AFD" ]] && [[ $AFD_ENDPOINT ]] && [ ! $(grep "BLOB_AFD_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] \
&& [[ $(curl --write-out '%{http_code}' --silent --output /dev/null {https://$AFD_ENDPOINT}) == "200" ]] \
&& wp plugin activate w3-total-cache --path=$WORDPRESS_HOME --allow-root \
&& wp w3-total-cache option set cdn.azure.cname $AFD_ENDPOINT --type=array --path=$WORDPRESS_HOME --allow-root; then
    afd_update_site_url
    service atd stop
    redis-cli flushall
elif [[ "$cdn_type" == "AFD" ]] && [[ $AFD_ENDPOINT ]] && [ ! $(grep "AFD_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] \
&& [[ $(curl --write-out '%{http_code}' --silent --output /dev/null {https://$AFD_ENDPOINT}) == "200" ]]; then
    afd_update_site_url
    service atd stop
    redis-cli flushall
else
    service atd start
    echo "bash /usr/local/bin/w3tc_cdn_config.sh $cdn_type" | at now +5 minutes
fi
