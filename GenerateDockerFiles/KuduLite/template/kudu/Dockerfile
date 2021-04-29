FROM BASE_IMAGE_NAME_PLACEHOLDER as main

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
  && apt-get install -y libreadline-dev bzip2 build-essential libssl-dev zlib1g-dev libpq-dev libsqlite3-dev \
  curl patch gawk g++ gcc git make libc6-dev patch libreadline6-dev libyaml-dev sqlite3 autoconf \
  libgdbm-dev libncurses5-dev automake libtool bison pkg-config libffi-dev bison libxslt-dev \
  libxml2-dev --no-install-recommends wget default-libmysqlclient-dev

# rbenv
RUN git clone https://github.com/rbenv/rbenv.git /usr/local/.rbenv
RUN chmod -R 777 /usr/local/.rbenv

ENV RBENV_ROOT="/usr/local/.rbenv"

ENV PATH="$RBENV_ROOT/bin:/usr/local:$PATH"

RUN git clone https://github.com/rbenv/ruby-build.git /usr/local/.rbenv/plugins/ruby-build
RUN chmod -R 777 /usr/local/.rbenv/plugins/ruby-build

RUN /usr/local/.rbenv/plugins/ruby-build/install.sh

# Install ruby 2.3.3 (default), 2.3.8, 2.4.5
ENV RUBY_CONFIGURE_OPTS=--disable-install-doc

ENV RUBY_CFLAGS=-O3

RUN apt-get install -y libssl1.0-dev
RUN eval "$(rbenv init -)" \
  && export WEBSITES_DEFAULT_RUBY_VERSION="2.3.3" \
  && rbenv install $WEBSITES_DEFAULT_RUBY_VERSION \
  && rbenv install "2.3.8" \
  && rbenv install "2.4.5" \
  && rbenv install "2.5.5" \
  && rbenv install "2.6.2" \
  && rbenv rehash \
  && rbenv global $WEBSITES_DEFAULT_RUBY_VERSION \
  && ls /usr/local -a \
  && rbenv local $WEBSITES_DEFAULT_RUBY_VERSION \
  && gem install bundler --version "=1.13.6" \
  && rbenv local 2.3.8 \
  && gem install bundler --version "=1.13.6" \
  && rbenv local 2.4.5 \
  && gem install bundler --version "=1.13.6" \
  && rbenv local 2.5.5 \
  && gem install bundler --version "=1.13.6" \
  && rbenv local 2.6.2 \
  && gem install bundler --version "=1.13.6" \
  && rbenv local $WEBSITES_DEFAULT_RUBY_VERSION \
  && chmod -R 777 /usr/local/.rbenv/versions \
  && chmod -R 777 /usr/local/.rbenv/version

RUN eval "$(rbenv init -)" \
  && rbenv global $WEBSITES_DEFAULT_RUBY_VERSION \
  && bundle config --global build.nokogiri -- --use-system-libraries

# Because Nokogiri tries to build libraries on its own otherwise
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES=true

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

ENV DOTNET_RUNNING_IN_CONTAINER=true

# Enable correct mode for dotnet watch (only mode supported in a container)
ENV DOTNET_USE_POLLING_FILE_WATCHER=true

# Skip extraction of XML docs - generally not useful within an image/container - helps performance
ENV NUGET_XMLDOC_MODE=skip

RUN dotnet tool install -g --version 2.2 dotnet-aspnet-codegenerator
ENV PATH=$PATH:/root/.dotnet/tools

#Install Kudu
RUN cd /tmp \
    && git clone https://github.com/Azure-App-Service/KuduLite.git \
    && cd ./KuduLite \
    && git checkout dev \
    && git log --format="%H" -n 1 > /kudu_commit.log \
    && cd ./Kudu.Services.Web \
    && benv dotnet=2.2 dotnet publish -c Release -o /opt/Kudu \
    && chmod 777 /opt/Kudu/Kudu.Services.Web.dll \
    && rm -rf /tmp/* \
    && chmod a+rw /var/nuget \
    && find /var/nuget -type d -exec chmod 777 {} \;

COPY startup.sh /

RUN chmod 777 /startup.sh

RUN benv node=9 npm=6 npm install -g kudusync
RUN benv node=9 npm=6 npm install pm2@latest -g

RUN ln -s /opt/nodejs/9/lib/node_modules/npm/bin/npm-cli.js /usr/bin/npm-cli.js

ENV PATH=$PATH:/opt/nodejs/9/bin

ENV KUDU_WEBSSH_PORT=3000
ENV KUDU_BUILD_VERSION=1.0.0

# Default App Settings for Main App Container SSH
ENV WEBSITE_SSH_USER=root
ENV WEBSITE_SSH_PASSWORD=Docker!

EXPOSE 8181

# Copy custom scripts
RUN mkdir /custom_scripts
COPY custom_scripts/* /custom_scripts/
RUN chmod 755 /custom_scripts/*

COPY deploy.bash.ruby.template /opt/Kudu/node_modules/kuduscript/lib/templates/deploy.bash.ruby.template
COPY deploy.bash.ruby.template /opt/Kudu/KuduConsole/node_modules/kuduscript/lib/templates/deploy.bash.ruby.template

# Patch, remove for future builds
RUN apt-get install -y libssl1.0-dev

ENTRYPOINT [ "/startup.sh" ]
CMD [ "1002", "kudu_group", "1001", "kudu_user", "localsite" ]
