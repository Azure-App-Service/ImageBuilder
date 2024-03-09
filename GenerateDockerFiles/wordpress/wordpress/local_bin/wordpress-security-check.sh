#!/bin/bash

if [ -d "/home/site/wwwroot/wp-content/plugins/azure_app_service_migration" ]; then
    rm -rf /home/site/wwwroot/wp-content/plugins/azure_app_service_migration/storage/AuthToken.txt 2> /dev/null
    rm -rf /var/www/wordpress/wp-content/plugins/azure_app_service_migration/storage/AuthToken.txt  2> /dev/null
    wp plugin deactivate azure_app_service_migration --quiet --path=$WORDPRESS_HOME --allow-root  2> /dev/null
    wp plugin delete azure_app_service_migration --quiet --path=$WORDPRESS_HOME --allow-root  2> /dev/null
fi
