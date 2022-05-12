#Verify CDN endpoint is live
response=$(curl --write-out '%{http_code}' --silent --output /dev/null {http://$CDN_ENDPOINT})

if [[ $response == "200" ]]; then
    #Configure CDN settings 
    if [[ $CDN_ENDPOINT ]]; then
        if wp w3-total-cache option set cdn.enabled true --type=boolean --path=$WORDPRESS_HOME --allow-root \
        && wp w3-total-cache option set cdn.engine "mirror" --path=$WORDPRESS_HOME --allow-root \
        && wp w3-total-cache option set cdn.mirror.domain $CDN_ENDPOINT --type=array --path=$WORDPRESS_HOME --allow-root; then
            echo "CDN_CONFIGURATION_COMPLETE" >> $WORDPRESS_LOCK_FILE
            #stop atd daemon
            service atd stop
        else
    	    service atd start
            echo 'bash /usr/local/bin/w3tc_cdn_config.sh' | at now +5 minutes
        fi
    fi
else
    service atd start
    echo 'bash /usr/local/bin/w3tc_cdn_config.sh' | at now +5 minutes
fi
