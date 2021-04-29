FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build-env
WORKDIR /opt/Kudu
RUN apt-get update
RUN apt install -y nodejs npm

#Install Kudu
RUN cd /tmp \
    && git clone https://github.com/Azure-App-Service/KuduLite.git \
    && cd ./KuduLite \
    && git checkout user/sanemht/3.1MigrationRebased \
    && git log --format="%H" -n 1 > /kudu_commit.log \
    && cd ./Kudu.Services.Web \
    && dotnet publish -c Release -r linux-x64 --self-contained true -p:PublishSingleFile=false -p:PublishTrimmed=true -p:PublishReadyToRun=true -o /opt/Kudu \
    && chmod 777 /opt/Kudu/Kudu.Services.Web

FROM BASE_IMAGE_NAME_PLACEHOLDER as main

ENV DEBIAN_FRONTEND noninteractive
ENV ENABLE_DYNAMIC_INSTALL=true
ENV DYNAMIC_INSTALL_ENABLED=true
ENV ORYX_SDK_STORAGE_BASE_URL=https://oryx-cdn.microsoft.io
ENV NODE_VERSION 10.22.0
ENV DOTNET_RUNNING_IN_CONTAINER=true
# Enable correct mode for dotnet watch (only mode supported in a container)
ENV DOTNET_USE_POLLING_FILE_WATCHER=true
# Skip extraction of XML docs - generally not useful within an image/container - helps performance
ENV NUGET_XMLDOC_MODE=skip
ENV KUDU_WEBSSH_PORT=3000
# Default App Settings for Main App Container SSH
ENV WEBSITE_SSH_USER=root
ENV WEBSITE_SSH_PASSWORD=Docker!

ENV KUDU_BUILD_VERSION=1.0.0

COPY webssh.zip ssh /tmp/
COPY --from=build-env /kudu_commit.log /kudu_commit.log

# NET5 - Root Certs Update ANT 92
RUN echo "deb http://deb.debian.org/debian bullseye main" >> /etc/apt/sources.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
     ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && sed -i '$ d' /etc/apt/sources.list

# Install webssh
RUN mkdir /opt/webssh \
  && unzip /tmp/webssh.zip -d /opt/webssh \
  && rm -rf /tmp/webssh.zip \
# Install Dependencies
  && apt-get update \
  && apt-get install -y libreadline-dev bzip2 build-essential libssl-dev zlib1g-dev libpq-dev libsqlite3-dev \
  curl patch gawk g++ gcc git make libc6-dev patch libreadline6-dev libyaml-dev sqlite3 autoconf \
  libgdbm-dev libncurses5-dev automake libtool bison pkg-config libffi-dev bison libxslt-dev \
  libxml2-dev --no-install-recommends wget default-libmysqlclient-dev \
  && wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb \
  && apt-get install apt-transport-https --no-install-recommends \
  && dpkg -i packages-microsoft-prod.deb \
  && apt-get install -y openssh-client --no-install-recommends \
  && apt-get install -y vim tree --no-install-recommends \
  && apt-get install -y tcptraceroute --no-install-recommends \
  && apt-get autoclean --no-install-recommends \
# Install Squashfs tools for KuduLite build
  && apt-get install -y squashfs-tools \
  && wget -O /usr/bin/tcpping http://www.vdberg.org/~richard/tcpping \
  && chmod 755 /usr/bin/tcpping \
# Enable SSH for Kudu Console
  && apt-get install -y ssh \
# Replace ssh with wrapper script for CIFS mount permissions workaround
  && mv /usr/bin/ssh /usr/bin/ssh.original \
  && mv /tmp/ssh /usr/bin/ssh \
  && chown root:root /usr/bin/ssh \
  && chmod 755 /usr/bin/ssh \
  && sed -i '/^#Port* /s/^#//' /etc/ssh/sshd_config \
  && sed -i '/^#PermitRootLogin* /s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
  && sed -i '/^#PrintLastLog* /s/^#PrintLastLog yes/PrintLastLog no/' /etc/ssh/sshd_config \
  && chmod -R 0644 /etc/update-motd.d/ \
# Install Kudu
  && mkdir -p /opt/Kudu/local \
  && mkdir -p /node_modules \
  && chmod -R 777 /node_modules \
  && chmod 755 /opt/Kudu/local \
  && apt-get  install -y unzip --no-install-recommends \
# Install pm2 and pm2-logrotate
  && mkdir -p /home/LogFiles \
  && chmod -R 777 /home \
  && rm -rf /tmp/* \
  && rm -rf /var/lib/apt/lists/*

# Install NODE 10.19
RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" \
  && case "${dpkgArch##*-}" in \
    amd64) ARCH='x64';; \
    ppc64el) ARCH='ppc64le';; \
    s390x) ARCH='s390x';; \
    arm64) ARCH='arm64';; \
    armhf) ARCH='armv7l';; \
    i386) ARCH='x86';; \
    *) echo "unsupported architecture"; exit 1 ;; \
  esac \
  # gpg keys listed at https://github.com/nodejs/node#release-keys
  && set -ex \
  && for key in \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
  # smoke tests
  && node --version \
  && npm --version \
  && ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm-cli.js \
  && ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/bin/npm-cli.js \
  && rm -rf /tmp/* \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build-env /opt/Kudu /opt/Kudu

COPY startup.sh /

RUN chmod 777 /startup.sh \
  && pam-auth-update \
  && npm install -g kudusync \
  && npm install pm2@latest -g \
  && rm -rf /tmp/* \
  && mkdir -p /tmp/BuildScriptGenerator \
# Needed for permission uses, as KuduLite runs under a different user
  && chmod -R 777 /tmp

EXPOSE 8181

ENTRYPOINT [ "/startup.sh" ]
CMD [ "1002", "kudu_group", "1001", "kudu_user", "localsite" ]
