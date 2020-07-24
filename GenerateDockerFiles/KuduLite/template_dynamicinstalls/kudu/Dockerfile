FROM BASE_IMAGE_NAME_PLACEHOLDER as main

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
  && apt-get install -y libreadline-dev bzip2 build-essential libssl-dev zlib1g-dev libpq-dev libsqlite3-dev \
  curl patch gawk g++ gcc git make libc6-dev patch libreadline6-dev libyaml-dev sqlite3 autoconf \
  libgdbm-dev libncurses5-dev automake libtool bison pkg-config libffi-dev bison libxslt-dev \
  libxml2-dev --no-install-recommends wget default-libmysqlclient-dev

ENV ENABLE_DYNAMIC_INSTALL=true
ENV ORYX_SDK_STORAGE_BASE_URL=https://oryx-cdn.microsoft.io

RUN wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
RUN apt-get install apt-transport-https
RUN dpkg -i packages-microsoft-prod.deb

#RUN add-apt-repository universe
#RUN apt-get install apt-transport-https

RUN apt-get install -y libssl1.0-dev

# Install dependencies
RUN apt-get update \
  && apt-get install -y openssh-client --no-install-recommends \
  && apt-get install -y vim tree --no-install-recommends \
  && apt-get install -y tcptraceroute \
# Install Squashfs tools for KuduLite build
  && apt-get install -y squashfs-tools \
  && wget -O /usr/bin/tcpping http://www.vdberg.org/~richard/tcpping \
  && chmod 755 /usr/bin/tcpping \
  && apt-get install -y libclamav9=0.102.3+dfsg-0~deb9u1 \
    clamav-freshclam=0.102.3+dfsg-0~deb9u1 \
    clamav=0.102.3+dfsg-0~deb9u1 \
  && freshclam

# Enable SSH for Kudu Console
RUN apt-get install -y ssh \
   && sed -i '/^#Port* /s/^#//' /etc/ssh/sshd_config \
   && sed -i '/^#PermitRootLogin* /s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
   && sed -i '/^#PrintLastLog* /s/^#PrintLastLog yes/PrintLastLog no/' /etc/ssh/sshd_config \
   && chmod -R 0644 /etc/update-motd.d/

COPY webssh.zip ssh /tmp/

# Install Kudu
RUN mkdir -p /opt/Kudu/local \
  && mkdir -p /node_modules \
  && chmod -R 777 /node_modules \
  && chmod 755 /opt/Kudu/local \
  && apt-get update \
  && apt-get  install -y unzip \
# Install pm2 and pm2-logrotate
  && mkdir -p /home/LogFiles \
# Install webssh
  && mkdir /opt/webssh \
  && unzip /tmp/webssh.zip -d /opt/webssh \
# Replace ssh with wrapper script for CIFS mount permissions workaround
  && mv /usr/bin/ssh /usr/bin/ssh.original \
  && mv /tmp/ssh /usr/bin/ssh \
  && chown root:root /usr/bin/ssh \
  && chmod 755 /usr/bin/ssh \
  && chmod -R 777 /home \
  && rm -rf /tmp/*

RUN oryx prep --skip-detection --platforms-and-versions "dotnet=2.2.8,nodejs=10.19.0"

ENV DOTNET_RUNNING_IN_CONTAINER=true

# Enable correct mode for dotnet watch (only mode supported in a container)
ENV DOTNET_USE_POLLING_FILE_WATCHER=true

# Skip extraction of XML docs - generally not useful within an image/container - helps performance
ENV NUGET_XMLDOC_MODE=skip

# Build KuduLite
ENV PATH=$PATH:/root/.dotnet/tools:/tmp/oryx/platforms/nodejs/10.19.0/bin:/tmp/oryx/platforms/nodejs/:/tmp/oryx/platforms/dotnet/2.2.8/bin:/usr/bin
RUN ln -s /tmp/oryx/platforms/nodejs/10.19.0/lib/node_modules/npm/bin/npm-cli.js /usr/bin/npm-cli.js
RUN benv dotnet=2.2.8 dotnet tool install -g --version 2.2 dotnet-aspnet-codegenerator

#Install Kudu
RUN cd /tmp \
    && git clone https://github.com/Azure-App-Service/KuduLite.git \
    && cd ./KuduLite \
    && git checkout dev \
    && git log --format="%H" -n 1 > /kudu_commit.log \
    && cd ./Kudu.Services.Web \
    && cat /tmp/KuduLite/Kudu.Services.Web//updateNodeModules.sh \
    && benv dotnet=2.2.8 dotnet publish -c Release -o /opt/Kudu \
    && chmod 777 /opt/Kudu/Kudu.Services.Web.dll \
    && chmod a+rw /var/nuget \
    && find /var/nuget -type d -exec chmod 777 {} \; \
    && rm -rf /tmp/KuduLite

COPY startup.sh /

RUN chmod 777 /startup.sh

RUN ls /tmp/oryx/platforms/nodejs/10.19.0/bin
RUN benv node=10.19.0 npm install -g kudusync
RUN benv node=10.19.0 npm install pm2@latest -g

ENV KUDU_WEBSSH_PORT=3000

# Default App Settings for Main App Container SSH
ENV WEBSITE_SSH_USER=root
ENV WEBISTE_SSH_PASSWORD=Docker!

# Copy custom scripts
RUN mkdir /custom_scripts
COPY custom_scripts/* /custom_scripts/
RUN chmod 755 /custom_scripts/*

RUN chmod -R 777 /tmp/*

EXPOSE 8181

ENTRYPOINT [ "/startup.sh" ]
CMD [ "1002", "kudu_group", "1001", "kudu_user", "localsite" ]
