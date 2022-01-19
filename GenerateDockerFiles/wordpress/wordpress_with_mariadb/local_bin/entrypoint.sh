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

setup_wordpress(){
	if ! [ -e wp-includes/version.php ]; then
        echo "INFO: There in no wordpress, going to GIT pull...:"
        while [ -d $WORDPRESS_HOME ]
        do
            mkdir -p /home/bak
            mv $WORDPRESS_HOME /home/bak/wordpress_bak$(date +%s)            
        done
        GIT_REPO=${GIT_REPO:-https://github.com/azureappserviceoss/wordpress-azure}
	    GIT_BRANCH=${GIT_BRANCH:-linux-appservice}
	    echo "INFO: ++++++++++++++++++++++++++++++++++++++++++++++++++:"
	    echo "REPO: "$GIT_REPO
	    echo "BRANCH: "$GIT_BRANCH
	    echo "INFO: ++++++++++++++++++++++++++++++++++++++++++++++++++:"
    
	    echo "INFO: Clone from "$GIT_REPO		
        git clone $GIT_REPO $WORDPRESS_HOME	&& cd $WORDPRESS_HOME
	    if [ "$GIT_BRANCH" != "master" ];then
		    echo "INFO: Checkout to "$GIT_BRANCH
		    git fetch origin
	        git branch --track $GIT_BRANCH origin/$GIT_BRANCH && git checkout $GIT_BRANCH
	    fi

        #remove .git
        rm  -rf $WORDPRESS_HOME/.git
        
        echo "INFO: Installing WordPress..."
        wp core install --url=$WEBSITE_HOSTNAME --title="${WORDPRESS_TITLE}" --admin_user=$WORDPRESS_ADMIN_USER --admin_password=$WORDPRESS_ADMIN_PASSWORD --admin_email=$WORDPRESS_ADMIN_EMAIL --skip-email --path=$WORDPRESS_HOME --allow-root
        wp rewrite structure '/%year%/%monthnum%/%day%/%postname%/' --path=$WORDPRESS_HOME --allow-root
        wp option set rss_user_excerpt 1 --path=$WORDPRESS_HOME --allow-root
        wp option set page_comments 1 --path=$WORDPRESS_HOME --allow-root

        echo "INFO: Installing W3TC plugin..."
        wp plugin install w3-total-cache --activate --path=$WORDPRESS_HOME --allow-root
        wp w3-total-cache import $WORDPRESS_SOURCE/w3tc-config.json --path=$WORDPRESS_HOME --allow-root

        echo "INFO: Installing Smush plugin..."
        wp plugin install wp-smushit --activate --path=$WORDPRESS_HOME --allow-root
        wp option set skip-smush-setup 1 --path=$WORDPRESS_HOME --allow-root
        wp option patch update wp-smush-settings auto 1 --path=$WORDPRESS_HOME --allow-root
        wp option patch update wp-smush-settings lossy 0 --path=$WORDPRESS_HOME --allow-root
        wp option patch update wp-smush-settings strip_exif 1 --path=$WORDPRESS_HOME --allow-root
        wp option patch update wp-smush-settings original 1 --path=$WORDPRESS_HOME --allow-root
        wp option patch update wp-smush-settings lazy_load 0 --path=$WORDPRESS_HOME --allow-root
        wp option patch update wp-smush-settings usage 0 --path=$WORDPRESS_HOME --allow-root

    else
        echo "INFO: There is one wordpress exist, no need to GIT pull again."
    fi
	
	# Although in AZURE, we still need below chown cmd.
    chown -R nginx:nginx $WORDPRESS_HOME
}

update_localdb_config(){    
	DATABASE_HOST=${DATABASE_HOST:-127.0.0.1}
	DATABASE_NAME=${DATABASE_NAME:-azurelocaldb}    
    export DATABASE_HOST DATABASE_NAME DATABASE_USERNAME DATABASE_PASSWORD   
}

echo "Setup openrc ..." && openrc && touch /run/openrc/softlevel

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

# That wp-config.php doesn't exist means WordPress is not installed/configured yet.
if [ ! -e "$WORDPRESS_HOME/wp-config.php" ] || [ ! -e "$WORDPRESS_HOME/wp-includes/version.php" ]; then
	echo "INFO: $WORDPRESS_HOME/wp-config.php or wp-includes/version.php not found."
	echo "Installing WordPress ..."
	setup_wordpress
	echo "Wordpress Setup Complete ..."
fi

if [  -e "$WORDPRESS_HOME/wp-config.php" ]; then
    echo "INFO: Check SSL Setting..."    
    SSL_DETECTED=$(grep "\$_SERVER\['HTTPS'\] = 'on';" $WORDPRESS_HOME/wp-config.php)
    if [ ! SSL_DETECTED ];then
        echo "INFO: Add SSL Setting..."
        sed -i "/stop editing!/r $WORDPRESS_SOURCE/ssl-settings.txt" $WORDPRESS_HOME/wp-config.php        
    else        
        echo "INFO: SSL Setting is exist!"
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

echo "Starting Redis ..."
redis-server &

if [ ! $AZURE_DETECTED ]; then	
    echo "NOT in AZURE, Start crond, log rotate..."	
    crond	
fi 

test ! -d "$SUPERVISOR_LOG_DIR" && echo "INFO: $SUPERVISOR_LOG_DIR not found. creating ..." && mkdir -p "$SUPERVISOR_LOG_DIR"
test ! -d "$NGINX_LOG_DIR" && echo "INFO: Log folder for nginx/php not found. creating..." && mkdir -p "$NGINX_LOG_DIR"
test ! -e /home/50x.html && echo "INFO: 50x file not found. createing..." && cp /usr/share/nginx/html/50x.html /home/50x.html
test -d "/home/etc/nginx" && echo "/home/etc/nginx exists.." && ln -s /home/etc/nginx /etc/nginx && ln -sf /usr/lib/nginx/modules /home/etc/nginx/modules
test ! -d "/home/etc/nginx" && mkdir -p /home/etc && cp -R /etc/nginx /home/etc/ && rm -rf /etc/nginx && ln -s /home/etc/nginx /etc/nginx && ln -sf /usr/lib/nginx/modules /home/etc/nginx/modules

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
echo "Starting SSH ..."
echo "Starting php-fpm ..."
echo "Starting Nginx ..."

cd /usr/bin/
supervisord -c /etc/supervisord.conf

