#!/bin/bash

# set -e

php -v

# if defined, assume the container is running on Azure
AZURE_DETECTED=$WEBSITES_ENABLE_APP_SERVICE_STORAGE


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
    test ! -d /home/site/temp-root && mkdir -p /home/site/temp-root
    cp -r /usr/src/temp-server/* /home/site/temp-root/
    cp /usr/src/nginx/temp-server.conf /etc/nginx/conf.d/default.conf
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
    
    #ensure correct default.conf before starting WordPress server
    if [[ $SETUP_PHPMYADMIN ]] && [[ "$SETUP_PHPMYADMIN" == "true" || "$SETUP_PHPMYADMIN" == "TRUE" || "$SETUP_PHPMYADMIN" == "True" ]]; then
        cp /usr/src/nginx/wordpress-phpmyadmin-server.conf /etc/nginx/conf.d/default.conf
    else
        cp /usr/src/nginx/wordpress-server.conf /etc/nginx/conf.d/default.conf
    fi
}

temp_server_stop() {
    #kill any existing nginx processes
    killall nginx 2> /dev/null 
}

setup_phpmyadmin() {
    if [ ! $(grep "PHPMYADMIN_INSTALLED" $WORDPRESS_LOCK_FILE) ]; then
        if [[ $SETUP_PHPMYADMIN ]] && [[ "$SETUP_PHPMYADMIN" == "true" || "$SETUP_PHPMYADMIN" == "TRUE" || "$SETUP_PHPMYADMIN" == "True" ]]; then
            if mkdir -p $PHPMYADMIN_HOME \
                && cp -R $PHPMYADMIN_SOURCE/phpmyadmin/* $PHPMYADMIN_HOME \
                && cp $PHPMYADMIN_SOURCE/config.inc.php $PHPMYADMIN_HOME/config.inc.php \
                && chmod 555 $PHPMYADMIN_HOME/config.inc.php; then
                echo "PHPMYADMIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
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
        
    IS_TEMP_SERVER_STARTED="False"
    #Start server with static webpage until wordpress is installed
    if [ ! $(grep "FIRST_TIME_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) ]; then
        echo "INFO: Starting temporary server while WordPress is being installed"
        IS_TEMP_SERVER_STARTED="True"
        temp_server_start
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
        
        mkdir -p $WORDPRESS_HOME
        echo "INFO: Pulling WordPress code"
        if cp -r $WORDPRESS_SOURCE/wordpress-azure/* $WORDPRESS_HOME; then
            echo "WORDPRESS_PULL_COMPLETED" >> $WORDPRESS_LOCK_FILE
        fi
    fi

    if [ $(grep "WORDPRESS_PULL_COMPLETED" $WORDPRESS_LOCK_FILE) ] &&  [ ! $(grep "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) ]; then
        if wp core install --url=$WEBSITE_HOSTNAME --title="WordPress on Azure" --admin_user=$WORDPRESS_ADMIN_USER --admin_password=$WORDPRESS_ADMIN_PASSWORD --admin_email=$WORDPRESS_ADMIN_EMAIL --skip-email --path=$WORDPRESS_HOME --allow-root; then
            echo "WP_INSTALLATION_COMPLETED" >> $WORDPRESS_LOCK_FILE
        fi
    fi

    if [ $(grep "WP_INSTALLATION_COMPLETED" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "WP_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) ]; then
        if wp rewrite structure '/%year%/%monthnum%/%day%/%postname%/' --path=$WORDPRESS_HOME --allow-root \
        && wp option set rss_user_excerpt 1 --path=$WORDPRESS_HOME --allow-root \
        && wp option set page_comments 1 --path=$WORDPRESS_HOME --allow-root \
        && wp option update blogdescription "" --path=$WORDPRESS_HOME --allow-root \
        && wp option set auto_update_core_major disabled --path=$WORDPRESS_HOME --allow-root \
        && wp option set auto_update_core_minor disabled --path=$WORDPRESS_HOME --allow-root \
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
    
    if [ $(grep "W3TC_PLUGIN_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "CDN_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "BLOB_STORAGE_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ]; then
        if [[ $CDN_ENABLED ]] && [[ "$CDN_ENABLED" == "true" || "$CDN_ENABLED" == "TRUE" || "$CDN_ENABLED" == "True" ]];then
            if [[ $CDN_ENDPOINT ]]; then
                echo "INFO: Scheduling CDN configuration 15 minutes from now.."
                #start atd daemon
                service atd start
                service atd status
                echo 'bash /usr/local/bin/w3tc_cdn_config.sh' | at now +10 minutes
            fi
        fi
    fi

    if [ $(grep "W3TC_PLUGIN_CONFIG_UPDATED" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "FIRST_TIME_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "BLOB_STORAGE_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ] && [ ! $(grep "CDN_CONFIGURATION_COMPLETE" $WORDPRESS_LOCK_FILE) ]; then
        if [[ $BLOB_STORAGE_ENABLED ]] && [[ "$BLOB_STORAGE_ENABLED" == "true" || "$BLOB_STORAGE_ENABLED" == "TRUE" || "$BLOB_STORAGE_ENABLED" == "True" ]] \
        && [[ $STORAGE_ACCOUNT_NAME ]] && [[ $STORAGE_ACCOUNT_KEY ]] && [[ $BLOB_CONTAINER_NAME ]]; then
            BLOB_STORAGE_URL="${STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
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

setup_nginx() {
    test ! -d "$NGINX_LOG_DIR" && echo "INFO: Log folder for nginx/php not found. creating..." && mkdir -p "$NGINX_LOG_DIR"
    test -d "/home/etc/nginx" && echo "/home/etc/nginx exists.." && rm -rf /etc/nginx && ln -s /home/etc/nginx /etc/nginx && ln -sf /usr/lib/nginx/modules /home/etc/nginx/modules
    test ! -d "/home/etc/nginx" && mkdir -p /home/etc && cp -R /etc/nginx /home/etc/ && rm -rf /etc/nginx && ln -s /home/etc/nginx /etc/nginx && ln -sf /usr/lib/nginx/modules /home/etc/nginx/modules
}

setup_and_run_startup_script() {
    test ! -d "/home/dev" && echo "INFO: /home/dev not found. Creating..." && mkdir -p /home/dev
    touch /home/dev/startup.sh
    bash /home/dev/startup.sh
}

echo "Setup openrc ..." && openrc && touch /run/openrc/softlevel

#moving /etc/nginx to /home/etc/nginx
#/home directory is mounted to persistent storage
#This enables custom configuration of nginx
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

if [ -e "$WORDPRESS_HOME/wp-config.php" ]; then
    echo "INFO: Check SSL Setting..."    
    SSL_DETECTED=$(grep "\$_SERVER\['HTTPS'\] = 'on';" $WORDPRESS_HOME/wp-config.php)
    if [ ! SSL_DETECTED ];then
        echo "INFO: Add SSL Setting..."
        sed -i "/stop editing!/r $WORDPRESS_SOURCE/ssl-settings.txt" $WORDPRESS_HOME/wp-config.php        
    else        
        echo "INFO: SSL Settings exist!"
    fi
fi

# set permalink as 'Day and Name' and default, it has best performance with nginx re_write config.
# PERMALINK_DETECTED=$(grep "\$wp_rewrite->set_permalink_structure" $WORDPRESS_HOME/wp-settings.php)
# if [ ! $PERMALINK_DETECTED ];then
#     echo "INFO: Set Permalink..."
#     init_string="do_action( 'init' );"
#     sed -i "/$init_string/r $WORDPRESS_SOURCE/permalink-settings.txt" $WORDPRESS_HOME/wp-settings.php
#     init_row=$(grep "$init_string" -n $WORDPRESS_HOME/wp-settings.php | head -n 1 | cut -d ":" -f1)
#     sed -i "${init_row}d" $WORDPRESS_HOME/wp-settings.php
# else
#     echo "INFO: Permalink setting is exist!"
# fi

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

setup_and_run_startup_script

echo "Starting SSH ..."
echo "Starting php-fpm ..."
echo "Starting Nginx ..."

if [ "$IS_TEMP_SERVER_STARTED" == "True" ]; then
    #stop temporary server
    temp_server_stop
fi

cd /usr/bin/
supervisord -c /etc/supervisord.conf


