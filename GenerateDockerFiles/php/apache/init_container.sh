#!/bin/bash
cat >/etc/motd <<EOL 
  _____                               
  /  _  \ __________ _________   ____  
 /  /_\  \\___   /  |  \_  __ \_/ __ \ 
/    |    \/    /|  |  /|  | \/\  ___/ 
\____|__  /_____ \____/ |__|    \___  >
        \/      \/                  \/ 
A P P   S E R V I C E   O N   L I N U X

Documentation: http://aka.ms/webapp-linux
PHP quickstart: https://aka.ms/php-qs
PHP version : `php -v | head -n 1 | cut -d ' ' -f 2`
Note: Any data outside '/home' is not persisted
EOL
cat /etc/motd

# Get environment variables to show up in SSH session
eval $(printenv | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/"/\\\"/g' | sed '/=/s//="/' | sed 's/$/"/' >> /etc/profile)

# Enable trigger profiling in xdebug
if [ "${WEBSITE_PROFILER_ENABLE_TRIGGER^^}" = TRUE ] ; then 
  echo 'xdebug.profiler_enable_trigger=1' >> /usr/local/etc/php/conf.d/php.ini;
  echo 'xdebug.profiler_enable=0' >> /usr/local/etc/php/conf.d/php.ini;
else
  sed -i "s/xdebug.profiler_enable_trigger=1//g" /usr/local/etc/php/conf.d/php.ini
  sed -i "s/xdebug.profiler_enable=0//g" /usr/local/etc/php/conf.d/php.ini
fi

# redirect php custom logs to stderr
if [ "${WEBSITE_ENABLE_PHP_ACCESS_LOGS^^}" = TRUE ] ; then 
	sed -i "s/CustomLog \/dev\/null combined/CustomLog \/dev\/stderr combined/g" /etc/apache2/apache2.conf; 
fi

# Set default APACHE_SERVER_LIMIT if not provided by customer
if [[ -z "${APACHE_SERVER_LIMIT}" ]]; then
    APACHE_SERVER_LIMIT="1000"
    export APACHE_SERVER_LIMIT="$APACHE_SERVER_LIMIT"
fi

# Set default APACHE_MAX_REQ_WORKERS if not provided by customer
if [[ -z "${APACHE_MAX_REQ_WORKERS}" ]]; then
    APACHE_MAX_REQ_WORKERS="256"
    export APACHE_MAX_REQ_WORKERS="$APACHE_MAX_REQ_WORKERS"
fi

# Replace the values in mpm_prefork.conf for Apache to take them up
sed -i "s/APACHE_SERVER_LIMIT/$APACHE_SERVER_LIMIT/g" /etc/apache2/mods-available/mpm_prefork.conf
sed -i "s/APACHE_MAX_REQ_WORKERS/$APACHE_MAX_REQ_WORKERS/g" /etc/apache2/mods-available/mpm_prefork.conf

# starting sshd process
sed -i "s/SSH_PORT/$SSH_PORT/g" /etc/ssh/sshd_config
/usr/sbin/sshd

appPath="/home/site/wwwroot"
runFromPath="/tmp/webapp"
startupCommandPath="/opt/startup/startup.sh"
userStartupCommand="$@"
if [ -z "$userStartupCommand" ]
then
  userStartupCommand="apache2-foreground";
else
  userStartupCommand="$userStartupCommand; apache2-foreground;"
fi

oryxArgs="create-script -appPath $appPath -output $startupCommandPath \
    -bindPort $PORT -startupCommand '$userStartupCommand'"

echo "Running oryx $oryxArgs"
eval oryx $oryxArgs
$startupCommandPath
