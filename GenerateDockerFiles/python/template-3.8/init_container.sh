#!/usr/bin/env bash

cat >/etc/motd <<EOL 

  _____                               
  /  _  \ __________ _________   ____  
 /  /_\  \\___   /  |  \_  __ \_/ __ \ 
/    |    \/    /|  |  /|  | \/\  ___/ 
\____|__  /_____ \____/ |__|    \___  >
        \/      \/                  \/ 

A P P   S E R V I C E   O N   L I N U X

Documentation: http://aka.ms/webapp-linux
`python --version`
Note: Any data outside '/home' is not persisted
EOL
cat /etc/motd

sed -i "s/SSH_PORT/$SSH_PORT/g" /etc/ssh/sshd_config
service ssh start

# Get environment variables to show up in SSH session
eval $(printenv | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/"/\\\"/g' | sed '/=/s//="/' | sed 's/$/"/' >> /etc/profile)

echo "$@" > /opt/startup/startupCommand
chmod 755 /opt/startup/startupCommand

oryxArgs='create-script -appPath /home/site/wwwroot -output /opt/startup/startup.sh -virtualEnvName antenv -defaultApp /opt/defaultsite'
if [ $# -eq 0 ]; then
    echo 'App Command Line not configured, will attempt auto-detect'
else
    echo "Site's appCommandLine: $@" 
    if [ $# -eq 1 ]; then
        echo "Checking of $1 is a file"
        if [ -f $1 ]; then
            echo 'App command line is a file on disk'
            fileContents=$(head -1 $1)
            #if the file ends with .sh
            if [ ${1: -3} == ".sh" ]; then
                echo 'App command line is a shell script, will execute this script as startup script'
                chmod +x $1
                oryxArgs+=" -userStartupCommand $1"
            else
                echo "$1 file exists on disk, reading its contents to run as startup arguments"
            echo "Contents of startupScript: $fileContents"
            oryxArgs+=" -userStartupCommand '$fileContents'"
            fi
        else
            echo 'App command line is not a file on disk, using it as the startup command.'
            oryxArgs+=" -userStartupCommand '$1'"
        fi
    else
       oryxArgs+=" -userStartupCommand '$@'"
    fi
fi

debugArgs=""
if [ "$APPSVC_REMOTE_DEBUGGING" == "TRUE" ]; then
    echo "App will launch in debug mode"
    debugArgs="-debugAdapter ptvsd -debugPort $APPSVC_TUNNEL_PORT"

    if [ "$APPSVC_REMOTE_DEBUGGING_BREAK" == "TRUE" ]; then
        debugArgs+=" -debugWait"
    fi

    oryxArgs="$oryxArgs $debugArgs"
fi

echo "Launching oryx with: $oryxArgs"
#invoke oryx to generate startup script
eval "oryx $oryxArgs"
chmod +x /opt/startup/startup.sh
#launch startup script
exec /opt/startup/startup.sh 


