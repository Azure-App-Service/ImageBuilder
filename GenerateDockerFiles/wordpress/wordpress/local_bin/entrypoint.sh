#!/bin/bash

# set -e

php -v

# if defined, assume the container is running on Azure
AZURE_DETECTED=$WEBSITES_ENABLE_APP_SERVICE_STORAGE
if [[ $AFD_CUSTOM_DOMAIN ]] && [[ $AFD_ENABLED ]] && [[ "$AFD_ENABLED" == "true" || "$AFD_ENABLED" == "TRUE" || "$AFD_ENABLED" == "True" ]]; then
    CUSTOM_DOMAIN=$AFD_CUSTOM_DOMAIN
fi

update_php_config() {
	local CONFIG_FILE="${1}"
	local PARAM_NAME="${2}"
	local PARAM_VALUE="${3}"
	local VALUE_TYPE="${4}"
	local PARAM_UPPER_BOUND="${5}"

	if [[ -e $CONFIG_FILE && $PARAM_VALUE ]]; then
		local FINAL_PARAM_VALUE

		if [[ "$VALUE_TYPE" == "NUM" && $PARAM_VALUE =~ ^[0-9]+$ && $PARAM_UPPER_BOUND =~ ^[0-9]+$ ]]; then

			if [[ "$PARAM_VALUE" -le "$PARAM_UPPER_BOUND" ]]; then
				FINAL_PARAM_VALUE=$PARAM_VALUE
			else
				FINAL_PARAM_VALUE=$PARAM_UPPER_BOUND
			fi

		elif [[ "$VALUE_TYPE" == "MEM" && $PARAM_VALUE =~ ^[0-9]+M$ && $PARAM_UPPER_BOUND =~ ^[0-9]+M$ ]]; then

			if [[ "${PARAM_VALUE::-1}" -le "${PARAM_UPPER_BOUND::-1}" ]]; then
				FINAL_PARAM_VALUE=$PARAM_VALUE
			else
				FINAL_PARAM_VALUE=$PARAM_UPPER_BOUND
			fi

		elif [[ "$VALUE_TYPE" == "TOGGLE" ]] && [[ "$PARAM_VALUE" == "On" || "$PARAM_VALUE" == "Off" ]]; then
			FINAL_PARAM_VALUE=$PARAM_VALUE
		fi


		if [[ $FINAL_PARAM_VALUE ]]; then
			echo "updating php config value "$PARAM_NAME
			sed -i "s/.*$PARAM_NAME.*/$PARAM_NAME = $FINAL_PARAM_VALUE/" $CONFIG_FILE
		fi
	fi
}

temp_server_start() {
    local TEMP_SERVER_TYPE="${1}"
    test ! -d /home/site/temp-root && mkdir -p /home/site/temp-root
    cp -r /usr/src/temp-server/* /home/site/temp-root/

    if [[ "$TEMP_SERVER_TYPE" == "INSTALLATION" ]]; then
        cp /usr/src/nginx/temp-server-installation.conf /etc/nginx/conf.d/default.conf
    elif [[ "$TEMP_SERVER_TYPE" == "MAINTENANCE" ]]; then     
        cp /usr/src/nginx/temp-server-maintenance.conf /etc/nginx/conf.d/default.conf
    else 
        echo "WARN: Unable to start temporary server. Missing parameter."
        return;
    fi

    local try_count=1
    while [ $try_count -le 10 ]
    do 
        /usr/sbin/nginx
        local port=`netstat -nlt|grep 80|wc -l`
        local process=`ps -ef |grep nginx|grep -v grep |wc -l`
        if [ $port -ge 1 ] && [ $process -ge 1 ]; then 
            echo "INFO: Temporary Server started... "            
            break
        else            
            echo "INFO: Nginx couldn't start, trying again..."
            killall nginx 2> /dev/null 
            sleep 5s
        fi
        let try_count+=1 
    done
}

temp_server_stop() {
    #kill any existing nginx processes
    killall nginx 2> /dev/null 
}

phpmyadmin_version_check() {
    version_line=$(grep -o "Version [0-9]\+\.[0-9]\+\.[0-9]\+" /$PHPMYADMIN_HOME/README)
    version_number=$(echo "$version_line" | awk '{print $2}')
    echo "$version_number"
}

get_php_version() {
    php_version_output=$(php -v 2>&1)

    # The pattern 'PHP X.Y.Z' is matched by grep, and awk is used to extract the version number (X.Y.Z)
    php_version=$(echo "$php_version_output" | grep -o 'PHP [0-9]\+\.[0-9]\+\.[0-9]\+' | awk '{print $2}')

    echo "$php_version"
}
#php -v min compatibility version in docker file (under if)

setup_phpmyadmin() {
    if [ ! $(grep "PHPMYADMIN_INSTALLED" $WORDPRESS_LOCK_FILE) ]; then
        if [[ $SETUP_PHPMYADMIN ]] && [[ "$SETUP_PHPMYADMIN" == "true" || "$SETUP_PHPMYADMIN" == "TRUE" || "$SETUP_PHPMYADMIN" == "True" ]]; then
            if mkdir -p $PHPMYADMIN_HOME \
                && chmod -R 777 $PHPMYADMIN_HOME \
                && cp -R $PHPMYADMIN_SOURCE/phpmyadmin/* $PHPMYADMIN_HOME \
                && cp $PHPMYADMIN_SOURCE/config.inc.php $PHPMYADMIN_HOME/config.inc.php \
                && chmod 555 $PHPMYADMIN_HOME/config.inc.php; then
                echo "PHPMYADMIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
            fi
        fi
    else
        CURRENT_VERSION=$(phpmyadmin_version_check)
        if [ $CURRENT_VERSION != $PHPMYADMIN_LATEST_VERSION ]; then
            CURRENT_PHP_VERSION=$(get_php_version)
            if [[ "$(printf '%s\n' "$LOWEST_COMPATIBLE_PHP_VERSION" "$CURRENT_PHP_VERSION" | sort -V | head -n1)" == "$LOWEST_COMPATIBLE_PHP_VERSION" ]]; then
                if [ -d $PHPMYADMIN_HOME ]; then
                    rm -rf $PHPMYADMIN_HOME/*
                fi
                # Copy files from /usr/src/phpmyadmin to /home/phpmyadmin
                if mkdir -p $PHPMYADMIN_HOME \
                    && chmod -R 777 $PHPMYADMIN_HOME \
                    && cp -R $PHPMYADMIN_SOURCE/phpmyadmin/* $PHPMYADMIN_HOME \
                    && cp $PHPMYADMIN_SOURCE/config.inc.php $PHPMYADMIN_HOME/config.inc.php \
                    && chmod 555 $PHPMYADMIN_HOME/config.inc.php; then
                    echo "PHPMYADMIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
                fi
            fi
        fi
    fi
}

translate_welcome_content() {
    if [  $(grep "WP_LANGUAGE_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) ] &&  [ ! $(grep "WP_TRANSLATE_WELCOME_DATA_COMPLETED" $WORDPRESS_LOCK_FILE) ] &&  [ ! $(grep "FIRST_TIME_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) ]; then
        if [[ $WORDPRESS_LOCALE_CODE ]] && [[ ! "$WORDPRESS_LOCALE_CODE" == "en_US"  ]]; then
            local welcomedatapath="$WORDPRESS_SOURCE/welcome-data/$WORDPRESS_LOCALE_CODE"
            local blogname=$(cat "$welcomedatapath/$WORDPRESS_LOCALE_CODE.blogname" 2>/dev/null)
	        local blogdesc=$(cat "$welcomedatapath/$WORDPRESS_LOCALE_CODE.blogdesc" 2>/dev/null)
	        local postname=$(cat "$welcomedatapath/$WORDPRESS_LOCALE_CODE.postname" 2>/dev/null)
	        local postcontent=$(cat "$welcomedatapath/$WORDPRESS_LOCALE_CODE.postcontent" 2>/dev/null)

            if [[ $postname ]] && [[ $postcontent ]] && [[ $blogname ]] && [[ $blogdesc ]]; then
                if wp option update blogname "$blogname" --path=$WORDPRESS_HOME --allow-root \
                && wp option update blogdescription "$blogdesc" --path=$WORDPRESS_HOME --allow-root \
                && wp post delete 1 --force --path=$WORDPRESS_HOME --allow-root \
                && wp post create --post_content="$postcontent" --post_title="$postname" --post_status=publish --path=$WORDPRESS_HOME --allow-root; then
                    echo "WP_TRANSLATE_WELCOME_DATA_COMPLETED" >> $WORDPRESS_LOCK_FILE
                fi
            else
                echo "WP_TRANSLATE_WELCOME_DATA_COMPLETED" >> $WORDPRESS_LOCK_FILE
            fi
        else
            echo "WP_TRANSLATE_WELCOME_DATA_COMPLETED" >> $WORDPRESS_LOCK_FILE
        fi
    fi
}

setup_cdn_variables() {
    IS_CDN_ENABLED="False"
    if [[ $CDN_ENABLED ]] && [[ "$CDN_ENABLED" == "true" || "$CDN_ENABLED" == "TRUE" || "$CDN_ENABLED" == "True" ]] && [[ $CDN_ENDPOINT ]]; then
    	IS_CDN_ENABLED="True"
    fi
    
    IS_AFD_ENABLED="False"
    if [[ $AFD_ENABLED ]] && [[ "$AFD_ENABLED" == "true" || "$AFD_ENABLED" == "TRUE" || "$AFD_ENABLED" == "True" ]] && [[ $AFD_ENDPOINT ]]; then
    	IS_AFD_ENABLED="True"
    fi
    
    IS_BLOB_STORAGE_ENABLED="False"
    if [[ $BLOB_STORAGE_ENABLED ]] && [[ "$BLOB_STORAGE_ENABLED" == "true" || "$BLOB_STORAGE_ENABLED" == "TRUE" || "$BLOB_STORAGE_ENABLED" == "True" ]] \
    && [[ $STORAGE_ACCOUNT_NAME ]] && [[ $STORAGE_ACCOUNT_KEY ]] && [[ $BLOB_CONTAINER_NAME ]]; then
	IS_BLOB_STORAGE_ENABLED="True"
    fi

}

start_at_daemon() {
    service atd start
    service atd status
}

setup_wordpress() {
    if [ ! -d $WORDPRESS_LOCK_HOME ]; then
        mkdir -p $WORDPRESS_LOCK_HOME
    fi

    if [ ! -e $WORDPRESS_LOCK_FILE ]; then
        echo "INFO: creating a new WordPress status file ..."
        touch $WORDPRESS_LOCK_FILE;
    else 
        echo "INFO: Found an existing WordPress status file ..."
    fi
        
    if [ "$IS_TEMP_SERVER_STARTED" == "True" ]; then
        temp_server_stop
    fi

    IS_TEMP_SERVER_STARTED="False"
    #Start server with static webpage until wordpress is installed
    if [ ! $(grep "FIRST_TIME_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) ]; then
        echo "INFO: Starting temporary server while WordPress is being installed"
        IS_TEMP_SERVER_STARTED="True"
        temp_server_start "INSTALLATION"
    fi

    setup_phpmyadmin

    if [ $(grep "GIT_PULL_COMPLETED" $WORDPRESS_LOCK_FILE) ] &&  [ ! $(grep "WORDPRESS_PULL_COMPLETED" $WORDPRESS_LOCK_FILE) ]; then
        echo "WORDPRESS_PULL_COMPLETED" >> $WORDPRESS_LOCK_FILE
    fi

    if [ ! $(grep "WORDPRESS_PULL_COMPLETED" $WORDPRESS_LOCK_FILE) ]; then
        while [ -d $WORDPRESS_HOME ]
        do
            mkdir -p /home/bak
            mv $WORDPRESS_HOME /home/bak/wordpress_bak$(date +%s)            
        done
        
        test ! -d "$WORDPRESS_HOME" && mkdir -p $WORDPRESS_HOME
        echo "INFO: Pulling WordPress code"
        if cp -r $WORDPRESS_SOURCE/wordpress-azure/* $WORDPRESS_HOME; then
            echo "WORDPRESS_PULL_COMPLETED" >> $WORDPRESS_LOCK_FILE
        fi
    fi

    if [ $(grep "WORDPRESS_PULL_COMPLETED" $WORDPRESS_LOCK_FILE) ] &&  [ ! $(grep "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) ]; then
        if wp core install --url=$WEBSITE_HOSTNAME --title="WordPress on Azure" --admin_user=$WORDPRESS_ADMIN_USER --admin_password=$WORDPRESS_ADMIN_PASSWORD --admin_email=$WORDPRESS_ADMIN_EMAIL --skip-email --path=$WORDPRESS_HOME --allow-root; then
            echo "WP_INSTALLATION_COMPLETED" >> $WORDPRESS_LOCK_FILE
        fi
        
        # one time check for WordPress core minor version update
        if [[ `wp core check-update --minor --path=$WORDPRESS_HOME --allow-root | grep Success | wc -l` -le 0 ]]; then
    	    wp core update --minor --path=$WORDPRESS_HOME --allow-root
    	fi
    fi

    if [ $(grep "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "WP_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) ]; then
        if wp rewrite structure '/%year%/%monthnum%/%day%/%postname%/' --path=$WORDPRESS_HOME --allow-root \
        && wp option set rss_user_excerpt 1 --path=$WORDPRESS_HOME --allow-root \
        && wp option set page_comments 1 --path=$WORDPRESS_HOME --allow-root \
        && wp option update blogdescription "" --path=$WORDPRESS_HOME --allow-root \
        && wp option set auto_update_core_major disabled --path=$WORDPRESS_HOME --allow-root \
        && wp option set auto_update_core_minor enabled --path=$WORDPRESS_HOME --allow-root \
        && wp option set auto_update_core_dev disabled --path=$WORDPRESS_HOME --allow-root; then
            echo "WP_CONFIG_UPDATED" >> $WORDPRESS_LOCK_FILE
        fi
    fi

    if [ $(grep "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "SMUSH_PLUGIN_INSTALLED" $WORDPRESS_LOCK_FILE) ]; then
        #backward compatibility for previous versions that don't have plugin source code in wordpress repo.
        if [ $(grep "GIT_PULL_COMPLETED" $WORDPRESS_LOCK_FILE) ]; then
            if wp plugin install wp-smushit --force --activate --path=$WORDPRESS_HOME --allow-root; then
                echo "SMUSH_PLUGIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
            fi
        else
            if wp plugin deactivate wp-smushit --quiet --path=$WORDPRESS_HOME --allow-root \
            && wp plugin activate wp-smushit --path=$WORDPRESS_HOME --allow-root; then
                echo "SMUSH_PLUGIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
            fi
        fi
    fi

    if [ $(grep "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "EMAIL_PLUGIN_INSTALLED" $WORDPRESS_LOCK_FILE) ] && [[ $WP_EMAIL_CONNECTION_STRING ]] ; then
        if wp plugin deactivate app_service_email --quiet --path=$WORDPRESS_HOME --allow-root \
        && wp plugin activate app_service_email --path=$WORDPRESS_HOME --allow-root; then
            echo "EMAIL_PLUGIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
        fi
    fi

    if [ $(grep "SMUSH_PLUGIN_INSTALLED" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "SMUSH_PLUGIN_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) ]; then
        if wp option set skip-smush-setup 1 --path=$WORDPRESS_HOME --allow-root \
        && wp option patch update wp-smush-settings auto 1 --path=$WORDPRESS_HOME --allow-root \
        && wp option patch update wp-smush-settings lossy 0 --path=$WORDPRESS_HOME --allow-root \
        && wp option patch update wp-smush-settings strip_exif 1 --path=$WORDPRESS_HOME --allow-root \
        && wp option patch update wp-smush-settings original 1 --path=$WORDPRESS_HOME --allow-root \
        && wp option patch update wp-smush-settings lazy_load 0 --path=$WORDPRESS_HOME --allow-root \
        && wp option patch update wp-smush-settings usage 0 --path=$WORDPRESS_HOME --allow-root; then
            echo "SMUSH_PLUGIN_CONFIG_UPDATED" >> $WORDPRESS_LOCK_FILE
        fi
    fi

    if [ $(grep "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "W3TC_PLUGIN_INSTALLED" $WORDPRESS_LOCK_FILE) ]; then
        #backward compatibility for previous versions that don't have plugin source code in wordpress repo.
        if [ $(grep "GIT_PULL_COMPLETED" $WORDPRESS_LOCK_FILE) ]; then
            if wp plugin install w3-total-cache --force --activate --path=$WORDPRESS_HOME --allow-root; then
                echo "W3TC_PLUGIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
            fi
        else
            if wp plugin deactivate w3-total-cache --quiet --path=$WORDPRESS_HOME --allow-root \
            && wp plugin activate w3-total-cache --path=$WORDPRESS_HOME --allow-root; then
                echo "W3TC_PLUGIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
            fi
        fi
    fi

    if [ $(grep "W3TC_PLUGIN_INSTALLED" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "W3TC_PLUGIN_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) ]; then
        if mkdir -p $WORDPRESS_HOME/wp-content/cache/tmp \
        && mkdir -p $WORDPRESS_HOME/wp-content/w3tc-config \
        && wp w3-total-cache import $WORDPRESS_SOURCE/w3tc-config.json --path=$WORDPRESS_HOME --allow-root; then
            echo "W3TC_PLUGIN_CONFIG_UPDATED" >> $WORDPRESS_LOCK_FILE
        fi
    fi
    
    setup_cdn_variables
    
    if [ $(grep "W3TC_PLUGIN_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "BLOB_STORAGE_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] \
    && [ ! $(grep "FIRST_TIME_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) ] && [[ "$IS_BLOB_STORAGE_ENABLED" == "True" ]]; then

        if ! [[ $BLOB_STORAGE_URL ]]; then
            BLOB_STORAGE_URL="${STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
        fi

        if wp w3-total-cache import $WORDPRESS_SOURCE/w3tc-blob-config.json --path=$WORDPRESS_HOME --allow-root \
        && wp w3-total-cache option set cdn.azure.user $STORAGE_ACCOUNT_NAME --path=$WORDPRESS_HOME --allow-root \
        && wp w3-total-cache option set cdn.azure.container $BLOB_CONTAINER_NAME --path=$WORDPRESS_HOME --allow-root \
        && wp w3-total-cache option set cdn.azure.key $STORAGE_ACCOUNT_KEY --path=$WORDPRESS_HOME --allow-root \
        && wp w3-total-cache option set cdn.enabled true --type=boolean --path=$WORDPRESS_HOME --allow-root \
        && wp w3-total-cache option set cdn.azure.cname $BLOB_STORAGE_URL --type=array --path=$WORDPRESS_HOME --allow-root \
        && wp plugin deactivate w3-total-cache --quiet --path=$WORDPRESS_HOME --allow-root \
        && wp plugin activate w3-total-cache --path=$WORDPRESS_HOME --allow-root; then
            echo "BLOB_STORAGE_CONFIGURATION_COMPLETE" >> $WORDPRESS_LOCK_FILE
        fi
    fi
    
    if [ $(grep "W3TC_PLUGIN_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) ] && [ "$IS_CDN_ENABLED" == "True" ] \
    && [ ! $(grep "BLOB_CDN_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "CDN_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ]; then
        if [ "$IS_BLOB_STORAGE_ENABLED" == "True" ] && [ $(grep "BLOB_STORAGE_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] \
        && [ ! $(grep "BLOB_CDN_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ]; then
            start_at_daemon
            echo "bash /usr/local/bin/w3tc_cdn_config.sh BLOB_CDN" | at now +10 minutes
        elif [ ! $(grep "CDN_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ]; then
            start_at_daemon
            echo "bash /usr/local/bin/w3tc_cdn_config.sh CDN" | at now +10 minutes
        fi
    fi
    
    if [ $(grep "W3TC_PLUGIN_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) ] && [ "$IS_AFD_ENABLED" == "True" ] \
    && [ ! $(grep "BLOB_AFD_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "AFD_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ]; then
        if [ "$IS_BLOB_STORAGE_ENABLED" == "True" ] && [ $(grep "BLOB_STORAGE_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] \
        && [ ! $(grep "BLOB_AFD_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ]; then
            start_at_daemon
            echo "bash /usr/local/bin/w3tc_cdn_config.sh BLOB_AFD" | at now +2 minutes
        elif [ ! $(grep "AFD_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ]; then
            start_at_daemon
            echo "bash /usr/local/bin/w3tc_cdn_config.sh AFD" | at now +2 minutes
        fi
    fi

    if [  $(grep "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) ] &&  [ ! $(grep "WP_LANGUAGE_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) ] &&  [ ! $(grep "FIRST_TIME_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) ]; then
	    if [[ $WORDPRESS_LOCALE_CODE ]] && [[ ! "$WORDPRESS_LOCALE_CODE" == "en_US"  ]]; then
            if wp language core install $WORDPRESS_LOCALE_CODE --path=$WORDPRESS_HOME --allow-root \
                && wp site switch-language $WORDPRESS_LOCALE_CODE --path=$WORDPRESS_HOME --allow-root \
                && wp language theme install --all $WORDPRESS_LOCALE_CODE --path=$WORDPRESS_HOME --allow-root \
                && wp language plugin install --all $WORDPRESS_LOCALE_CODE --path=$WORDPRESS_HOME --allow-root \
                && wp language theme update --all --path=$WORDPRESS_HOME --allow-root \
                && wp language plugin update --all --path=$WORDPRESS_HOME --allow-root; then
                echo "WP_LANGUAGE_SETUP_COMPLETED" >> $WORDPRESS_LOCK_FILE
            fi
        else
            echo "WP_LANGUAGE_SETUP_COMPLETED" >> $WORDPRESS_LOCK_FILE
        fi
    fi

    translate_welcome_content

    if [ $(grep "W3TC_PLUGIN_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) ] && [ $(grep "SMUSH_PLUGIN_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) ] &&  [ ! $(grep "FIRST_TIME_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) ]; then
        echo "FIRST_TIME_SETUP_COMPLETED" >> $WORDPRESS_LOCK_FILE
    fi

    if [ ! $AZURE_DETECTED ]; then 
	    echo "INFO: NOT in Azure, chown for "$WORDPRESS_HOME 
	    chown -R nginx:nginx $WORDPRESS_HOME
    fi
}

setup_post_startup_script() {
    test ! -d "/home/dev" && echo "INFO: /home/dev not found. Creating..." && mkdir -p /home/dev
    touch /home/dev/startup.sh
}

setup_nginx() {
    test ! -d "$NGINX_LOG_DIR" && echo "INFO: Log folder for nginx/php not found. creating..." && mkdir -p "$NGINX_LOG_DIR"
}

echo "Setup openrc ..." && openrc && touch /run/openrc/softlevel

setup_nginx

if ! [[ $SKIP_WP_INSTALLATION ]] || ! [[ "$SKIP_WP_INSTALLATION" == "true" 
    || "$SKIP_WP_INSTALLATION" == "TRUE" || "$SKIP_WP_INSTALLATION" == "True" ]]; then

    if [ ! -e "$WORDPRESS_HOME/wp-config.php" ] || [ ! -e "$WORDPRESS_HOME/wp-includes/version.php" ]; then
        echo "INFO: $WORDPRESS_HOME/wp-config.php or wp-includes/version.php not found."
        rm -f $WORDPRESS_LOCK_FILE
    fi
    
    setup_wordpress
else 
    echo "INFO: Skipping WP installation..."
fi

# Runs migrate.sh.. Retries 3 times.
if [[ $MIGRATION_IN_PROGRESS ]] && [[ "$MIGRATION_IN_PROGRESS" == "true" || "$MIGRATION_IN_PROGRESS" == "TRUE" || "$MIGRATION_IN_PROGRESS" == "True" ]] && [[ $MIGRATE_NEW_DATABASE_NAME ]] && [[ $MIGRATE_MYSQL_DUMP_FILE ]] && [[ $MIGRATE_RETAIN_WP_FEATURES ]] && [ ! $(grep "MYSQL_DB_IMPORT_COMPLETED" $MYSQL_IMPORT_STATUSFILE_PATH) ] && [ ! $(grep "MYSQL_DB_IMPORT_FAILED" $MYSQL_IMPORT_STATUSFILE_PATH) ]; then
    service atd start
    echo "bash /usr/local/bin/migrate.sh 3" | at now +0 minutes
fi

afd_update_site_url() {
    if [[ $AFD_ENABLED ]] && [[ "$AFD_ENABLED" == "true" || "$AFD_ENABLED" == "TRUE" || "$AFD_ENABLED" == "True" ]]; then
        AFD_DOMAIN=$WEBSITE_HOSTNAME
        if [[ $CUSTOM_DOMAIN ]]; then
            AFD_DOMAIN=$CUSTOM_DOMAIN
        elif [[ $AFD_ENDPOINT ]]; then
            AFD_DOMAIN=$AFD_ENDPOINT
        fi

        if [ $(grep "BLOB_AFD_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] || [ $(grep "AFD_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] \
            || [ $(grep "MULTISITE_CONVERSION_COMPLETED" $WORDPRESS_LOCK_FILE) ]; then
            wp config set WP_HOME "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_HOME --allow-root
            wp config set WP_SITEURL "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_HOME --allow-root
            wp option update SITEURL "https://$AFD_DOMAIN" --path=$WORDPRESS_HOME --allow-root
            wp option update HOME "https://$AFD_DOMAIN" --path=$WORDPRESS_HOME --allow-root

            if [ -e "$WORDPRESS_HOME/wp-config.php" ]; then
                AFD_HEADER_FILE='afd-header-settings.txt'
                AFD_CONFIG_DETECTED=''

                if [[ $(grep "MULTISITE_CONVERSION_COMPLETED" $WORDPRESS_LOCK_FILE) ]] && [[ $WORDPRESS_MULTISITE_TYPE ]] && [[ "$WORDPRESS_MULTISITE_TYPE" == "subdomain" ]] && [[ $CUSTOM_DOMAIN ]]; then
                    AFD_CONFIG_DETECTED=$(grep "^\s*\$_SERVER\['HTTP_HOST'\]\s*=\s*\$_SERVER\['HTTP_X_FORWARDED_HOST'\];" $WORDPRESS_HOME/wp-config.php)
                    AFD_HEADER_FILE='afd-multisite-header-settings.txt'
                    AFD_DOMAIN=''
                else
                    AFD_CONFIG_DETECTED=$(grep "^\s*\$_SERVER\['HTTP_HOST'\]\s*=\s*getenv('AFD_DOMAIN');" $WORDPRESS_HOME/wp-config.php)
                fi

                if [ -z "$AFD_CONFIG_DETECTED" ]; then
                    SEARCH_STR_I="Using environment variables for memory limits"
                    if [ ! -z "$(grep "${SEARCH_STR_I}" $WORDPRESS_HOME/wp-config.php)" ]; then
                        sed -i "/${SEARCH_STR_I}/e cat $WORDPRESS_SOURCE/$AFD_HEADER_FILE" $WORDPRESS_HOME/wp-config.php
                    else
                        SEARCH_STR_II="Using environment variables for DB connection information"
                        if [ ! -z "$(grep "${SEARCH_STR_II}" $WORDPRESS_HOME/wp-config.php)" ]; then
                            sed -i "/${SEARCH_STR_II}/e cat $WORDPRESS_SOURCE/$AFD_HEADER_FILE" $WORDPRESS_HOME/wp-config.php
                        fi
                    fi
                fi
            fi
        fi

        if [[ "$AFD_DOMAIN" == "$WEBSITE_HOSTNAME" ]]; then
            AFD_DOMAIN=''
        fi
    fi
}

# Update AFD URL
afd_update_site_url


# Multi-site conversion
if [[ $(grep "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) ]] && [[ ! $(grep "MULTISITE_CONVERSION_COMPLETED" $WORDPRESS_LOCK_FILE) ]] \
    && [[ $WORDPRESS_MULTISITE_CONVERT ]] && [[ "$WORDPRESS_MULTISITE_CONVERT" == "true" || "$WORDPRESS_MULTISITE_CONVERT" == "TRUE" || "$WORDPRESS_MULTISITE_CONVERT" == "True" ]] \
    && [[ $WORDPRESS_MULTISITE_TYPE ]] && [[ "$WORDPRESS_MULTISITE_TYPE" == "subdirectory" || "$WORDPRESS_MULTISITE_TYPE" == "subdomain" ]] \
    && [[ ! "$(wp config get MULTISITE --path=$WORDPRESS_HOME --allow-root 2> /dev/null)" ]]; then

    IS_AFD_ENABLED="False"
    if [[ $AFD_ENABLED ]] && [[ "$AFD_ENABLED" == "true" || "$AFD_ENABLED" == "TRUE" || "$AFD_ENABLED" == "True" ]]; then
    	IS_AFD_ENABLED="True"
    fi

    IS_W3TC_ENABLED="False"
    if wp plugin is-active w3-total-cache --path=$WORDPRESS_HOME --allow-root; then
        IS_W3TC_ENABLED="True"
    fi

    IS_SMUSHIT_ENABLED="False"
    if wp plugin is-active wp-smushit --path=$WORDPRESS_HOME --allow-root; then
        IS_SMUSHIT_ENABLED="True"
    fi

    ADD_SUBDOMAIN_FLAG=''
    MULTISITE_DOMAIN=$WEBSITE_HOSTNAME

    if [[ $CUSTOM_DOMAIN ]]; then
        MULTISITE_DOMAIN=$CUSTOM_DOMAIN
        if [[ "$WORDPRESS_MULTISITE_TYPE" == "subdomain" ]]; then
            ADD_SUBDOMAIN_FLAG='true'
        fi
    elif [[ "$IS_AFD_ENABLED" == "True" ]] && [[ $AFD_ENDPOINT ]] && [[ "$WORDPRESS_MULTISITE_TYPE" == "subdirectory" ]]; then
        MULTISITE_DOMAIN=$AFD_ENDPOINT
    fi

    if [[ "$WORDPRESS_MULTISITE_TYPE" == "subdomain" && "$MULTISITE_DOMAIN" != "$WEBSITE_HOSTNAME" ]] \
        || [[ "$WORDPRESS_MULTISITE_TYPE" == "subdirectory" ]]; then

        wp config set WP_HOME "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_HOME --allow-root
        wp config set WP_SITEURL "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_HOME --allow-root

        if wp plugin deactivate --all --path=$WORDPRESS_HOME --allow-root \
        && wp core multisite-convert ${ADD_SUBDOMAIN_FLAG:+--subdomains} --url=$MULTISITE_DOMAIN --path=$WORDPRESS_HOME --allow-root; then

            # Removing duplicate occurance of DOMAIN_CURRENT_SITE
            wp config delete DOMAIN_CURRENT_SITE --path=$WORDPRESS_HOME --allow-root 2> /dev/null;
            wp config set DOMAIN_CURRENT_SITE "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_HOME --allow-root 2> /dev/null;
            wp config set WP_HOME "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_HOME --allow-root 2> /dev/null;
            wp config set WP_SITEURL "\$http_protocol . \$_SERVER['HTTP_HOST']" --raw --path=$WORDPRESS_HOME --allow-root 2> /dev/null;
            wp option update SITEURL "https://$MULTISITE_DOMAIN" --path=$WORDPRESS_HOME --allow-root 2> /dev/null;
            wp option update HOME "https://$MULTISITE_DOMAIN" --path=$WORDPRESS_HOME --allow-root 2> /dev/null;
            echo "MULTISITE_CONVERSION_COMPLETED" >> $WORDPRESS_LOCK_FILE
        fi
    fi

    #Re-activate W3TC & SmushIt plugins
    if [[ "$IS_W3TC_ENABLED" == "True" ]]; then
        wp plugin activate w3-total-cache --path=$WORDPRESS_HOME --allow-root
    fi

    if [[ "$IS_SMUSHIT_ENABLED" == "True" ]]; then
        wp plugin activate wp-smushit --path=$WORDPRESS_HOME --allow-root
    fi

    # Update AFD URL
    afd_update_site_url
fi


# setup server root
if [ ! $AZURE_DETECTED ]; then 
    echo "INFO: NOT in Azure, chown for "$WORDPRESS_HOME 
    chown -R nginx:nginx $WORDPRESS_HOME
fi


# calculate Redis max memory 
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
Redis_Mem_UpperLimit=$(($RAM_KB*2/10))
Redis_Mem_KB=$(($RAM_KB/10))
if [[ $REDIS_MAX_MEMORY_MB =~ ^[0-9][0-9]*$ ]]; then
    if [[ $(($Redis_Mem_UpperLimit - $REDIS_MAX_MEMORY_MB*1024)) -ge 0 ]]; then 
        Redis_Mem_KB=$(($REDIS_MAX_MEMORY_MB*1024))
    else
        Redis_Mem_KB=$(($Redis_Mem_UpperLimit))
    fi
else
    echo "REDIS_MAX_MEMORY_MB must be an integer.."
fi
Redis_Mem_KB="${Redis_Mem_KB}KB"

echo "Starting Redis with Max Memory: ${Redis_Mem_KB}"
redis-server --maxmemory "$Redis_Mem_KB" --maxmemory-policy allkeys-lru &

if [ ! $AZURE_DETECTED ]; then	
    echo "NOT in AZURE, Start crond, log rotate..."	
    crond	
fi 


test ! -d "$SUPERVISOR_LOG_DIR" && echo "INFO: $SUPERVISOR_LOG_DIR not found. creating ..." && mkdir -p "$SUPERVISOR_LOG_DIR"
test ! -e /home/50x.html && echo "INFO: 50x file not found. creating..." && cp /usr/share/nginx/html/50x.html /home/50x.html

#Updating php configuration values
if [[ -e $PHP_CUSTOM_CONF_FILE ]]; then
    echo "INFO: Updating PHP configurations..."
    update_php_config $PHP_CUSTOM_CONF_FILE "file_uploads" $FILE_UPLOADS "TOGGLE"
    update_php_config $PHP_CUSTOM_CONF_FILE "memory_limit" $PHP_MEMORY_LIMIT "MEM" $UB_PHP_MEMORY_LIMIT
    update_php_config $PHP_CUSTOM_CONF_FILE "upload_max_filesize" $UPLOAD_MAX_FILESIZE "MEM" $UB_UPLOAD_MAX_FILESIZE
    update_php_config $PHP_CUSTOM_CONF_FILE "post_max_size" $POST_MAX_SIZE "MEM" $UB_POST_MAX_SIZE
    update_php_config $PHP_CUSTOM_CONF_FILE "max_execution_time" $MAX_EXECUTION_TIME "NUM" $UB_MAX_EXECUTION_TIME
    update_php_config $PHP_CUSTOM_CONF_FILE "max_input_time" $MAX_INPUT_TIME "NUM" $UB_MAX_INPUT_TIME
    update_php_config $PHP_CUSTOM_CONF_FILE "max_input_vars" $MAX_INPUT_VARS "NUM" $UB_MAX_INPUT_VARS
fi

echo "INFO: creating /run/php/php-fpm.sock ..."
test -e /run/php/php-fpm.sock && rm -f /run/php/php-fpm.sock
mkdir -p /run/php
touch /run/php/php-fpm.sock
chown nginx:nginx /run/php/php-fpm.sock
chmod 777 /run/php/php-fpm.sock

sed -i "s/SSH_PORT/$SSH_PORT/g" /etc/ssh/sshd_config
echo "Starting SSH ..."
echo "Starting php-fpm ..."
echo "Starting Nginx ..."

UNISON_EXCLUDED_PATH="wp-content/uploads"
IS_LOCAL_STORAGE_OPTIMIZATION_POSSIBLE="False"

if [[ $(grep "FIRST_TIME_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) ]] && [[ $WORDPRESS_LOCAL_STORAGE_CACHE_ENABLED ]] && [[ "$WORDPRESS_LOCAL_STORAGE_CACHE_ENABLED" == "1" || "$WORDPRESS_LOCAL_STORAGE_CACHE_ENABLED" == "true" || "$WORDPRESS_LOCAL_STORAGE_CACHE_ENABLED" == "TRUE" || "$WEBSITE_LOCAL_STORAGE_CACHE_ENABLED" == "True" ]]; then
    if [[ "$WEBSITE_SKU" == "LinuxFree" ]]; then
        MAXIMUM_LOCAL_STORAGE_SIZE_BYTES=$MAXIMUM_LOCAL_STORAGE_SIZE_BYTES_FREESKU
    fi

    CURRENT_WP_SIZE="`du -sb --apparent-size $WORDPRESS_HOME/ --exclude="wp-content/uploads" | cut -f1`"
    if [ "$CURRENT_WP_SIZE" -lt "$MAXIMUM_LOCAL_STORAGE_SIZE_BYTES" ]; then
        IS_LOCAL_STORAGE_OPTIMIZATION_POSSIBLE="True"
    else
        CURRENT_WP_SIZE="`du -sb --apparent-size $WORDPRESS_HOME/ --exclude="wp-content" | cut -f1`"
        if [ "$CURRENT_WP_SIZE" -lt "$MAXIMUM_LOCAL_STORAGE_SIZE_BYTES" ]; then
            IS_LOCAL_STORAGE_OPTIMIZATION_POSSIBLE="True"
            UNISON_EXCLUDED_PATH="wp-content"
        fi
    fi
fi
export UNISON_EXCLUDED_PATH


IS_AFD_ENABLED="False"
if [[ $AFD_ENABLED ]] && [[ "$AFD_ENABLED" == "true" || "$AFD_ENABLED" == "TRUE" || "$AFD_ENABLED" == "True" ]]; then
    IS_AFD_ENABLED="True"
fi

if [[ $SETUP_PHPMYADMIN ]] && [[ "$SETUP_PHPMYADMIN" == "true" || "$SETUP_PHPMYADMIN" == "TRUE" || "$SETUP_PHPMYADMIN" == "True" ]]; then
    if [[ $(grep "MULTISITE_CONVERSION_COMPLETED" $WORDPRESS_LOCK_FILE) ]] && [[ $WORDPRESS_MULTISITE_TYPE ]] && [[ "$WORDPRESS_MULTISITE_TYPE" == "subdirectory" ]]; then
        cp /usr/src/nginx/wordpress-subdirectory-multisite-phpmyadmin-server.conf /etc/nginx/conf.d/default.conf
    elif [[ $(grep "MULTISITE_CONVERSION_COMPLETED" $WORDPRESS_LOCK_FILE) ]] && [[ $WORDPRESS_MULTISITE_TYPE ]] && [[ "$WORDPRESS_MULTISITE_TYPE" == "subdomain" ]] && [[ "$IS_AFD_ENABLED" == "True" ]] && [[ $CUSTOM_DOMAIN ]]; then
        cp /usr/src/nginx/wordpress-subdomain-afd-multisite-phpmyadmin-server.conf /etc/nginx/conf.d/default.conf
    else
        cp /usr/src/nginx/wordpress-phpmyadmin-server.conf /etc/nginx/conf.d/default.conf
    fi
else
    if [[ $(grep "MULTISITE_CONVERSION_COMPLETED" $WORDPRESS_LOCK_FILE) ]] && [[ $WORDPRESS_MULTISITE_TYPE ]] && [[ "$WORDPRESS_MULTISITE_TYPE" == "subdirectory" ]]; then
        cp /usr/src/nginx/wordpress-subdirectory-multisite-server.conf /etc/nginx/conf.d/default.conf
    elif [[ $(grep "MULTISITE_CONVERSION_COMPLETED" $WORDPRESS_LOCK_FILE) ]] && [[ $WORDPRESS_MULTISITE_TYPE ]] && [[ "$WORDPRESS_MULTISITE_TYPE" == "subdomain" ]] && [[ "$IS_AFD_ENABLED" == "True" ]] && [[ $CUSTOM_DOMAIN ]]; then
        cp /usr/src/nginx/wordpress-subdomain-afd-multisite-server.conf /etc/nginx/conf.d/default.conf
    else
        cp /usr/src/nginx/wordpress-server.conf /etc/nginx/conf.d/default.conf
    fi
fi


if [ "$IS_LOCAL_STORAGE_OPTIMIZATION_POSSIBLE" == "True" ]; then
    cp /usr/src/supervisor/supervisord-stgoptmzd.conf /etc/supervisord.conf
    # updating the placeholders values in other files
    sed -i "s#WORDPRESS_HOME#${WORDPRESS_HOME}#g" /etc/supervisord.conf
    sed -i "s#HOME_SITE_LOCAL_STG#${HOME_SITE_LOCAL_STG}#g" /etc/supervisord.conf
    sed -i "s#UNISON_EXCLUDED_PATH#${UNISON_EXCLUDED_PATH}#g" /etc/supervisord.conf
    sed -i "s#UNISON_EXCLUDED_PATH#${UNISON_EXCLUDED_PATH}#g" /usr/local/bin/inotifywait-perms-service.sh
else
    cp /usr/src/supervisor/supervisord-original.conf /etc/supervisord.conf
fi

# Initial site's root directory is set to /home/site/wwwroot
sed -i "s#WORDPRESS_HOME#${WORDPRESS_HOME}#g" /etc/nginx/conf.d/default.conf

if [ "$IS_TEMP_SERVER_STARTED" == "True" ]; then
    temp_server_stop
fi

# Get environment variables to show up in SSH session
# This will replace any \ (backslash), " (double quote), $ (dollar sign) and ` (back quote) symbol by its escaped character to not allow any bash substitution.
(printenv | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/\\/\\\\/g' | sed 's/"/\\\"/g' | sed 's/\$/\\\$/g' | sed 's/`/\\`/g' | sed '/=/s//="/' | sed 's/$/"/' >> /etc/profile)

setup_post_startup_script

cd /usr/bin/
supervisord -c /etc/supervisord.conf

