FROM buildpack-deps:jessie-curl
LABEL maintainer="Azure App Services Container Images <appsvc-images@microsoft.com>"

ENV RUBY_VERSION=VERSION_PLACEHOLDER

RUN echo "deb http://deb.debian.org/debian/ jessie main" > /etc/apt/sources.list \
 && echo "deb-src http://deb.debian.org/debian/ jessie main" >> /etc/apt/sources.list \
 && echo "deb http://security.debian.org/ jessie/updates main" >> /etc/apt/sources.list \
 && echo "deb-src http://security.debian.org/ jessie/updates main" >> /etc/apt/sources.list \
 && echo "deb http://archive.debian.org/debian jessie-backports main" >> /etc/apt/sources.list \
 && echo "deb-src http://archive.debian.org/debian jessie-backports main" >> /etc/apt/sources.list \
 && echo "Acquire::Check-Valid-Until \"false\";" > /etc/apt/apt.conf

RUN apt-get update -qq

# Dependencies for various ruby and rubygem installations
RUN apt-get install -y --no-install-recommends libreadline-dev bzip2 build-essential libssl-dev zlib1g-dev libpq-dev \
  libsqlite3-dev patch gawk g++ gcc make libc6-dev patch libreadline6-dev libyaml-dev sqlite3 autoconf \
  libgdbm-dev libncurses5-dev automake libtool bison pkg-config libffi-dev bison libxslt-dev \
  libxml2-dev libmysqlclient-dev wget git net-tools dnsutils curl tcpdump iproute2

# rbenv 
ENV RBENV_ROOT="/usr/local/.rbenv"
RUN git clone https://github.com/rbenv/rbenv.git $RBENV_ROOT
RUN chmod -R 777 $RBENV_ROOT

ENV PATH="$RBENV_ROOT/bin:/usr/local:$PATH"

RUN git clone https://github.com/rbenv/ruby-build.git $RBENV_ROOT/plugins/ruby-build
RUN chmod -R 777 $RBENV_ROOT/plugins/ruby-build

RUN $RBENV_ROOT/plugins/ruby-build/install.sh

# Install ruby 
ENV RUBY_CONFIGURE_OPTS=--disable-install-doc

ENV RUBY_CFLAGS=-O3

RUN cd $RBENV_ROOT \
  && git pull

RUN eval "$(rbenv init -)" \
  && rbenv install --force $RUBY_VERSION \
  && rbenv rehash \
  && rbenv global $RUBY_VERSION \
  && ls /usr/local -a \
  && gem install bundler --version "=1.13.6" \
  && chmod -R 777 $RBENV_ROOT/versions \
  && chmod -R 777 $RBENV_ROOT/version

RUN eval "$(rbenv init -)" \
  && rbenv global $RUBY_VERSION \
  && bundle config --global build.nokogiri -- --use-system-libraries

# Because Nokogiri tries to build libraries on its own otherwise
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES=true

# SQL Server gem support
RUN apt-get install -y unixodbc-dev

# find latest version of FreeTDS ftp://ftp.freetds.org/pub/freetds/stable/
ENV FREETDS_VERSION=1.1.6
RUN wget ftp://ftp.freetds.org/pub/freetds/stable/freetds-$FREETDS_VERSION.tar.gz \
  && tar -xzf freetds-$FREETDS_VERSION.tar.gz \
  && rm freetds-$FREETDS_VERSION.tar.gz \
  && cd freetds-$FREETDS_VERSION \
  && ./configure --prefix=/usr/local --with-tdsver=7.3 \
  && make \
  && make install \
  && cd ..

# Make temp directory for ruby images
RUN mkdir -p /tmp/bundle
RUN chmod 777 /tmp/bundle

COPY init_container.sh /bin/
COPY startup.sh /opt/
COPY sshd_config /etc/ssh/
COPY hostingstart.html /opt/startup/hostingstart.html
COPY staticsite.rb /opt/staticsite.rb

RUN apt-get update -qq \
    && apt-get install -y nodejs openssh-server vim curl wget tcptraceroute --no-install-recommends \
    && echo "root:Docker!" | chpasswd \
    && echo "cd /home" >> /root/.bashrc

RUN eval "$(rbenv init -)" \
  && rbenv global $RUBY_VERSION

RUN chmod 755 /bin/init_container.sh \
  && mkdir -p /home/LogFiles/ \
  && chmod 755 /opt/startup.sh

EXPOSE 2222 8080

ENV PORT 8080
ENV SSH_PORT 2222
ENV WEBSITE_ROLE_INSTANCE_ID localRoleInstance
ENV WEBSITE_INSTANCE_ID localInstance
ENV PATH ${PATH}:/home/site/wwwroot

# install libssl1.0.2, and libssl1.1
# these links need to be updated constantly
# maybe save a copy locally
RUN wget http://ftp.us.debian.org/debian/pool/main/o/openssl1.0/libssl1.0.2_1.0.2u-1~deb9u1_amd64.deb \
  && dpkg -i libssl1.0.2_1.0.2u-1~deb9u1_amd64.deb \
  && wget http://ftp.us.debian.org/debian/pool/main/libx/libxcrypt/libcrypt1-udeb_4.4.16-1_amd64.udeb \
  && dpkg -i libcrypt1-udeb_4.4.16-1_amd64.udeb \
  && wget http://http.us.debian.org/debian/pool/main/g/glibc/libc6-udeb_2.28-10_amd64.udeb \
  && dpkg -i --force-overwrite libc6-udeb_2.28-10_amd64.udeb \
  && wget http://ftp.us.debian.org/debian/pool/main/o/openssl/libcrypto1.1-udeb_1.1.0l-1~deb9u1_amd64.udeb \
  && dpkg -i --force-overwrite libcrypto1.1-udeb_1.1.0l-1~deb9u1_amd64.udeb \
  && wget http://ftp.us.debian.org/debian/pool/main/o/openssl/libssl1.1-udeb_1.1.0l-1~deb9u1_amd64.udeb \
  && dpkg -i --force-overwrite libssl1.1-udeb_1.1.0l-1~deb9u1_amd64.udeb

WORKDIR /home/site/wwwroot

ENTRYPOINT [ "/bin/init_container.sh" ]
