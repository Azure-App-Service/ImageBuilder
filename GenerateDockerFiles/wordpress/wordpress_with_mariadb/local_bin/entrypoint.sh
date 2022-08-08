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

setup_mariadb_data_dir(){
    test ! -d "$MARIADB_DATA_DIR" && echo "INFO: $MARIADB_DATA_DIR not found. creating ..." && mkdir -p "$MARIADB_DATA_DIR"

    # check if 'mysql' database exists
    if [ ! -d "$MARIADB_DATA_DIR/mysql" ]; then
	    echo "INFO: 'mysql' database doesn't exist under $MARIADB_DATA_DIR. So we think $MARIADB_DATA_DIR is empty."
	    echo "Copying all data files from the original folder /var/lib/mysql to $MARIADB_DATA_DIR ..."
	    cp -R /var/lib/mysql/. $MARIADB_DATA_DIR
    else
	    echo "INFO: 'mysql' database already exists under $MARIADB_DATA_DIR."
    fi

    rm -rf /var/lib/mysql
    ln -s $MARIADB_DATA_DIR /var/lib/mysql
    chown -R mysql:mysql $MARIADB_DATA_DIR
    test ! -d /run/mysqld && echo "INFO: /run/mysqld not found. creating ..." && mkdir -p /run/mysqld
    chown -R mysql:mysql /run/mysqld
}

start_mariadb(){
    
    if test ! -e /run/mysqld/mysqld.sock; then
        touch /run/mysqld/mysqld.sock
    fi
    chmod 777 /run/mysqld/mysqld.sock
    mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
    /usr/bin/mysqld --user=mysql &
    
    #Alternate Mariadb Setup
    #/etc/init.d/mariadb setup --datadir=MARIADB_DATA_DIR
    #rc-service mariadb start

    #rm -f /tmp/mysql.sock
    #ln -s /var/run/mysqld/mysqld.sock /tmp/mysql.sock

    # create default database 'azurelocaldb'
    #mysql -u root -e "CREATE DATABASE IF NOT EXISTS azurelocaldb; FLUSH PRIVILEGES;"
    # make sure mysql service is started...
    
    port=`netstat -nlt|grep 3306|wc -l`
    process=`ps -ef |grep mysql|grep -v grep |wc -l`
    try_count=1

    while [ $try_count -le 10 ]
    do 
        if [ $port -eq 1 ] && [ $process -ge 1 ]; then 
            echo "INFO: MariaDB is running... "            
            break
        else            
            echo "INFO: Haven't found MariaDB Service this time, Wait 10s, try again..."
            sleep 10s
            let try_count+=1
            port=`netstat -nlt|grep 3306|wc -l`
            process=`ps -ef |grep mysql|grep -v grep |wc -l`    
        fi
    done    
}
#unzip phpmyadmin
setup_phpmyadmin(){
    test ! -d "$PHPMYADMIN_HOME" && echo "INFO: $PHPMYADMIN_HOME not found. creating..." && mkdir -p "$PHPMYADMIN_HOME"
    cd $PHPMYADMIN_SOURCE
    tar -xf phpMyAdmin.tar.gz -C $PHPMYADMIN_HOME --strip-components=1
    cp -R phpmyadmin-config.inc.php $PHPMYADMIN_HOME/config.inc.php    
    sed -i "/# Add locations of phpmyadmin here./r $PHPMYADMIN_SOURCE/phpmyadmin-locations.txt" /etc/nginx/conf.d/default.conf
	cd /
    # rm -rf $PHPMYADMIN_SOURCE
    if [ ! $AZURE_DETECTED ]; then
        echo "INFO: NOT in Azure, chown for "$PHPMYADMIN_HOME  
        chown -R nginx:nginx $PHPMYADMIN_HOME
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
        if wp plugin deactivate wp-smushit --quiet --path=$WORDPRESS_HOME --allow-root \
        && wp plugin activate wp-smushit --path=$WORDPRESS_HOME --allow-root; then
            echo "SMUSH_PLUGIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
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
        if wp plugin deactivate w3-total-cache --quiet --path=$WORDPRESS_HOME --allow-root \
        && wp plugin activate w3-total-cache --path=$WORDPRESS_HOME --allow-root; then
            echo "W3TC_PLUGIN_INSTALLED" >> $WORDPRESS_LOCK_FILE
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
    # Although in AZURE, we still need below chown cmd.
    chown -R nginx:nginx $WORDPRESS_HOME
}

update_localdb_config(){    
	DATABASE_HOST=${DATABASE_HOST:-127.0.0.1}
	DATABASE_NAME=${DATABASE_NAME:-azurelocaldb}    
    export DATABASE_HOST DATABASE_NAME DATABASE_USERNAME DATABASE_PASSWORD   
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

setup_wordpress_lock() {
    if [ ! -d $WORDPRESS_LOCK_HOME ]; then
        mkdir -p $WORDPRESS_LOCK_HOME
    fi

    if [ ! -e $WORDPRESS_LOCK_FILE ]; then
        echo "INFO: creating a new WordPress status file ..."
        touch $WORDPRESS_LOCK_FILE;
    else 
        echo "INFO: Found an existing WordPress status file ..."
    fi
}

temp_server_start() {
    mkdir -p /home/site/temp-root
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
    
    #ensure correct default.conf
    cp /usr/src/nginx/wordpress-server.conf /etc/nginx/conf.d/default.conf
}

temp_server_stop() {
    #kill any existing nginx processes
    killall nginx 2> /dev/null 
    rm -rf /home/site/temp-root
}

echo "Setup openrc ..." && openrc && touch /run/openrc/softlevel

#moving /etc/nginx to /home/etc/nginx
#/home directory is mounted to persistent storage
#This enables custom configuration of nginx
setup_nginx

setup_wordpress_lock

#Start temporary server with static webpage until wordpress is installed
IS_TEMP_SERVER_STARTED="False"
if [ ! $(grep "FIRST_TIME_SETUP_COMPLETED" $WORDPRESS_LOCK_FILE) ]; then
    echo "INFO: Starting temporary server while WordPress is being installed"
    IS_TEMP_SERVER_STARTED="True"
    temp_server_start
fi

DATABASE_TYPE=$(echo ${DATABASE_TYPE}|tr '[A-Z]' '[a-z]')
if [ "${DATABASE_TYPE}" == "local" ]; then
    echo "Starting MariaDB and PHPMYADMIN..."  
    echo 'mysql.default_socket = /run/mysqld/mysqld.sock' >> $PHP_CONF_FILE     
    echo 'mysqli.default_socket = /run/mysqld/mysqld.sock' >> $PHP_CONF_FILE     
    #setup MariaDB
    echo "INFO: loading local MariaDB and phpMyAdmin ..."
    echo "Setting up MariaDB data dir ..."
    setup_mariadb_data_dir
    echo "Setting up MariaDB log dir ..."
    test ! -d "$MARIADB_LOG_DIR" && echo "INFO: $MARIADB_LOG_DIR not found. creating ..." && mkdir -p "$MARIADB_LOG_DIR"
    chown -R mysql:mysql $MARIADB_LOG_DIR
    echo "Starting local MariaDB ..."
    start_mariadb
    echo "Installing phpMyAdmin ..."
    setup_phpmyadmin
    echo "Granting user for phpMyAdmin ..."
    # Set default value of username/password if they are't exist/null.
    DATABASE_USERNAME=${DATABASE_USERNAME:-phpmyadmin}
    DATABASE_PASSWORD=${DATABASE_PASSWORD:-MS173m_QN}
	echo "INFO: ++++++++++++++++++++++++++++++++++++++++++++++++++:"
    echo "phpmyadmin username:" $DATABASE_USERNAME
    echo "phpmyadmin password:" $DATABASE_PASSWORD
    echo "INFO: ++++++++++++++++++++++++++++++++++++++++++++++++++:"
    mysql -u root -e "GRANT ALL ON *.* TO \`$DATABASE_USERNAME\`@'localhost' IDENTIFIED BY '$DATABASE_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
    # create default database 'azurelocaldb'
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS azurelocaldb; FLUSH PRIVILEGES;"
    echo "INFO: local MariaDB is used."
    update_localdb_config
    # show_wordpress_db_config
    echo "Creating database for WordPress if not exists ..."
	mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$DATABASE_NAME\` CHARACTER SET utf8 COLLATE utf8_general_ci;"
	echo "Granting user for WordPress ..."
	mysql -u root -e "GRANT ALL ON \`$DATABASE_NAME\`.* TO \`$DATABASE_USERNAME\`@\`$DATABASE_HOST\` IDENTIFIED BY '$DATABASE_PASSWORD'; FLUSH PRIVILEGES;"        
fi

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
        echo "INFO: SSL Setting is exist!"
    fi
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

#Just In Case, use external DB before, change to Local DB this time.
if [ "$DATABASE_TYPE" == "local" ]; then
    PHPMYADMIN_SETTINGS_DETECTED=$(grep 'location /phpmyadmin' /etc/nginx/conf.d/default.conf )    
    if [ ! "$PHPMYADMIN_SETTINGS_DETECTED" ]; then
        sed -i "/# Add locations of phpmyadmin here./r $PHPMYADMIN_SOURCE/phpmyadmin-locations.txt" /etc/nginx/conf.d/default.conf
    fi
fi


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
