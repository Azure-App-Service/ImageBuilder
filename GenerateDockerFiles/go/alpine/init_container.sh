#!/bin/sh
cat >/etc/motd <<EOL 
  _____                               
  /  _  \ __________ _________   ____  
 /  /_\  \\___   /  |  \_  __ \_/ __ \ 
/    |    \/    /|  |  /|  | \/\  ___/ 
\____|__  /_____ \____/ |__|    \___  >
        \/      \/                  \/ 
A P P   S E R V I C E   O N   L I N U X

Documentation: http://aka.ms/webapp-linux
Note: Any data outside '/home' is not persisted

EOL
cat /etc/motd

# Get environment variables to show up in SSH session
eval $(printenv | awk -F= '{print "export " $1"="$2 }' >> /etc/profile)

# Starting sshd process
sed -i "s/SSH_PORT/$SSH_PORT/g" /etc/ssh/sshd_config
/usr/sbin/sshd

# Find a Go binary to run in /home/site/wwwroot/
executable=$(find /home/site/wwwroot/ -type f -executable -exec sh -c "file -i '{}' | grep -q 'x-executable; charset=binary'" \; -print -quit)

if [ -n "$executable" ]; then
    echo Running $executable now
    $executable
else
    echo Go Binary not found ... defaulting to hostingsite.html
    /opt/startup/hostingstart
fi
