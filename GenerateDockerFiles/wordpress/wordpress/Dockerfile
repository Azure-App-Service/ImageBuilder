FROM BASE_IMAGE_NAME_PLACEHOLDER
LABEL maintainer Azure App Service Container Images <appsvc-images@microsoft.com>
# ========
# ENV vars
# ========
# ssh
ENV SSH_PASSWD "root:Docker!"
ENV SSH_PORT 2222
#nginx
ENV NGINX_VERSION 1.22.1
ENV NGINX_LOG_DIR "/var/log/nginx"
#php
ENV PHP_HOME "/usr/local/etc/php"
ENV PHP_CONF_DIR $PHP_HOME
ENV PHP_CONF_FILE $PHP_CONF_DIR"/php.ini"
ENV PHP_CUSTOM_CONF_FILE $PHP_CONF_DIR"/conf.d/uploads.ini"
ENV PHP_FPM_LOG_DIR "/var/log/php-fpm"
#Upper bounds of php configs
ENV UB_PHP_MEMORY_LIMIT 512M
ENV UB_UPLOAD_MAX_FILESIZE 256M
ENV UB_POST_MAX_SIZE 256M
ENV UB_MAX_EXECUTION_TIME 120
ENV UB_MAX_INPUT_TIME 120
ENV UB_MAX_INPUT_VARS 10000
# phpmyadmin
ENV PHPMYADMIN_SOURCE "/usr/src/phpmyadmin"
ENV PHPMYADMIN_HOME "/home/phpmyadmin"
# redis
ENV PHPREDIS_VERSION 5.3.4
#Web Site Home
ENV HOME_SITE "/home/site/wwwroot"
ENV HOME_SITE_LOCAL_STG "/var/www/wordpress"
#Maximum local storage of 10GB
ENV MAXIMUM_LOCAL_STORAGE_SIZE_BYTES 10737418240
ENV MAXIMUM_LOCAL_STORAGE_SIZE_BYTES_FREESKU 536870912
# supervisor
ENV SUPERVISOR_LOG_DIR "/var/log/supervisor"
# wordpress
ENV WORDPRESS_SOURCE "/usr/src/wordpress"
ENV WORDPRESS_HOME "/home/site/wwwroot"
ENV WORDPRESS_LOCK_HOME "/home/wp-locks"
ENV WORDPRESS_LOCK_FILE $WORDPRESS_LOCK_HOME"/wp_deployment_status.txt"
ENV AFD_DOMAIN=
# Unison
ENV UNISON "/usr/local/unison"
ENV UNISON_LOG_DIR "/var/log/unison"
ENV UNISON_VERSION master
ENV FILESYNC_STATUS_FILE_DIR="/var/dev/filesync/"
ENV FILESYNC_STATUS_FILE_PATH="/var/dev/filesync/status.txt"
# docker
ENV DOCKER_BUILD_HOME "/dockerbuild"
# Migration
ENV MYSQL_IMPORT_STATUSFILE_PATH "/home/dev/migrate/mysql/mysql_import_status.txt"
ENV MYSQL_IMPORT_STATUSFILE_DIR "/home/dev/migrate/mysql/"
#
# --------
# ~. tools
# --------
RUN set -ex \
    && apk update \
    && apk add --update linux-headers \
    && apk add --no-cache openssl git net-tools tcpdump tcptraceroute vim curl wget bash\
	&& cd /usr/bin \
	&& wget http://www.vdberg.org/~richard/tcpping \
	&& chmod 777 tcpping \
# ========
# install the PHP extensions we need and xdebug
# ======== 
    && apk add --no-cache                  \
            --virtual .build-dependencies   \
                $PHPIZE_DEPS                \
                zlib-dev                    \
                cyrus-sasl-dev              \
                git                         \
                autoconf                    \
                g++                         \
                libtool                     \
                make                        \
                pcre-dev                    \    
            tini                            \
            libintl                         \
            icu                             \
            icu-dev                         \
            libxml2-dev                     \
            postgresql-dev                  \
            freetype-dev                    \
            libjpeg-turbo-dev               \
            libpng-dev                      \
            gmp                             \
            gmp-dev                         \
            libmemcached-dev                \
            imagemagick-dev                 \
            libssh2                         \
            libssh2-dev                     \
            libxslt-dev                     \    
    && docker-php-source extract \
    && pecl install xdebug-beta apcu \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && docker-php-ext-install exif \
	&& docker-php-ext-install soap \
    && docker-php-ext-install bcmath \
    && docker-php-ext-install -j "$(nproc)" \
	    mysqli \
		opcache \
		pdo_mysql \
		pdo_pgsql \
	&& docker-php-ext-enable apcu \
    && docker-php-source delete \
    && runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	&& apk add --virtual .drupal-phpexts-rundeps $runDeps \
	&& apk del .build-dependencies \	
	&& docker-php-source delete \
	&& mkdir -p /usr/local/php/tmp \
	&& chmod 777 /usr/local/php/tmp \
	&& apk add --no-cache sed \
# ------
# ssh
# ------
    && apk add --no-cache openssh-server \
    && echo "$SSH_PASSWD" | chpasswd \
#---------------
# at
#---------------
    && apk add --no-cache at \
#---------------
# openrc service
#---------------
   && apk add --no-cache openrc \
   && sed -i 's/"cgroup_add_service/" # cgroup_add_service/g' /lib/rc/sh/openrc-run.sh \
# ----------
# Nginx
# ---------- 
# Replace GPG_KEYS based on the key used to sign NGINX package
# or import the public key used to sign the NGINX package
# NGINX public keys can be found here: https://nginx.org/en/pgp_keys.html
# previous GPG_KEYS is "B0F4253373F8F6F510D42178520A9993A1C052F8"
# RUN set -ex\      
	&& GPG_KEYS=13C82A63B603576156E30A4EA0EA981B66B0D967 \
	&& CONFIG="\
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--modules-path=/usr/lib/nginx/modules \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--pid-path=/var/run/nginx.pid \
		--lock-path=/var/run/nginx.lock \
		--http-client-body-temp-path=/var/cache/nginx/client_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
		--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
		--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
		--user=nginx \
		--group=nginx \
		--with-http_ssl_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_mp4_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_random_index_module \
		--with-http_secure_link_module \
		--with-http_stub_status_module \
		--with-http_auth_request_module \
		--with-http_xslt_module=dynamic \
		--with-http_image_filter_module=dynamic \
		--with-http_geoip_module=dynamic \
		--with-threads \
		--with-stream \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-stream_realip_module \
		--with-stream_geoip_module=dynamic \
		--with-http_slice_module \
		--with-mail \
		--with-mail_ssl_module \
		--with-compat \
		--with-file-aio \
		--with-http_v2_module \
		--add-module=/usr/src/ngx_cache_purge-c7345057ad5429617fc0823e92e3fa8043840cef \
	" \
	&& addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& apk add --no-cache --virtual .build-deps \
		gcc \
		libc-dev \
		make \
		openssl-dev \
		pcre-dev \
		zlib-dev \
		linux-headers \
		curl \
		gnupg \
		libxslt-dev \
		gd-dev \
		geoip-dev \
	&& curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
	&& curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
	&& curl -fSL https://github.com/nullunit/ngx_cache_purge/archive/c7345057ad5429617fc0823e92e3fa8043840cef.zip -o ngx_cache_purge-2.3.zip \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& found=''; \
	for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $GPG_KEYS from $server"; \
		gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
	gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
	&& rm -rf "$GNUPGHOME" nginx.tar.gz.asc \
	&& mkdir -p /usr/src \
	&& tar -zxC /usr/src -f nginx.tar.gz \
	&& rm nginx.tar.gz \
	&& unzip ngx_cache_purge-2.3.zip -d /usr/src \
	&& rm ngx_cache_purge-2.3.zip \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& ./configure $CONFIG --with-debug \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& mv objs/nginx objs/nginx-debug \
	&& mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
	&& mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
	&& mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
	&& mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
	&& ./configure $CONFIG \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& install -m644 html/index.html /usr/share/nginx/html/ \
	&& install -m644 html/50x.html /usr/share/nginx/html/ \
	&& install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
	&& install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
	&& install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
	&& install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
	&& install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so \
	&& ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	&& rm -rf /usr/src/nginx-$NGINX_VERSION \
	&& rm -rf /usr/src/ngx_cache_purge-c7345057ad5429617fc0823e92e3fa8043840cef \
	\
	# Bring in gettext so we can get `envsubst`, then throw
	# the rest away. To do this, we need to install `gettext`
	# then move `envsubst` out of the way so `gettext` can
	# be deleted completely, then move `envsubst` back.
	&& apk add --no-cache --virtual .gettext gettext \
	&& mv /usr/bin/envsubst /tmp/ \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	&& apk add --no-cache --virtual .nginx-rundeps $runDeps \
	&& apk del .build-deps \
	&& apk del .gettext \
	&& mv /tmp/envsubst /usr/local/bin/ \
	\
	# Bring in tzdata so users could set the timezones through the environment
	# variables
	&& apk add --no-cache tzdata \
	\
	# forward request and error logs to docker log collector
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
	#
	# change default root path to $HOME_SITE
	&& mkdir -p /etc/nginx/conf.d \
    && mkdir -p ${HOME_SITE} \
	&& mkdir -p ${HOME_SITE_LOCAL_STG} \
    && echo "<?php phpinfo();" > $HOME_SITE/index.php \
    && chown -R nginx:nginx $HOME_SITE \
	&& chown -R nginx:nginx $HOME_SITE_LOCAL_STG \
	&& chmod -R 777 $HOME_SITE \
	&& chmod -R 777 $HOME_SITE_LOCAL_STG \
	# create php-fpm log directory
	&& mkdir -p ${PHP_FPM_LOG_DIR} \
	&& chown -R nginx:nginx $PHP_FPM_LOG_DIR \
	&& chmod -R 777 $PHP_FPM_LOG_DIR \
# -------------
# log rotate & supervisor
# -------------
	&& apk update \
	&& apk add logrotate supervisor \	
	# check log files once every minute, triaged by crond.
	&& echo "*       *       *       *       *       sh /usr/local/bin/triage-rotate.sh" >> /etc/crontabs/root \
# -------------
# phpmyadmin
# -------------
    && mkdir -p $PHPMYADMIN_SOURCE \
# ~. upgrade/clean up
# ----------
	&& apk upgrade \
	&& rm -rf /var/cache/apk/* \
    && rm -rf /tmp/* \
# =========
# Configure
# =========
# RUN set -ex\    		
	##
	&& rm -rf /var/log/nginx \
	##
	&& rm -rf /var/log/supervisor \
	## Just take care of nginx and php logs
	&& rm -rf /etc/logrotate.d \
	&& mkdir -p /etc/logrotate.d \
	&& rm -rf /usr/src/supervisor \
	&& mkdir -p /usr/src/supervisor \
# =========
# Brotli
# =========
	&& apk add --no-cache nginx-mod-http-brotli \
	&& apk add --no-cache --virtual .brotli-build-deps \
		g++ \
		make \
		autoconf \
		pkgconfig \
	&& mkdir -p /tmp/php-ext-brotli \
	&& cd /tmp/php-ext-brotli \
	&& git clone --recursive --depth=1 https://github.com/kjdev/php-ext-brotli.git /tmp/php-ext-brotli \
	&& phpize \
	&& ./configure \
	&& make \
	&& make install \
	&& rm -rf /tmp/php-ext-brotli \
	&& apk del .brotli-build-deps

# ====================
# Download and Install
# ~. tools
# 1. redis
# 2. wp-cli
# ====================
RUN set -ex \
    # --------
	# ~. tools
	# --------
    && apk update \
    && apk add --no-cache redis \
	# --------
	# 1. PHP extensions
	# -------- 
	# install the PHP extensions we need
	&& docker-php-source extract \
    && curl -L -o /tmp/redis.tar.gz https://github.com/phpredis/phpredis/archive/$PHPREDIS_VERSION.tar.gz \
    && tar xfz /tmp/redis.tar.gz \
    && rm -r /tmp/redis.tar.gz \
    && mv phpredis-$PHPREDIS_VERSION /usr/src/php/ext/redis	\
	&& apk add --no-cache --virtual .build-deps \
		libjpeg-turbo-dev \
		libpng-dev \
		libwebp-dev \
		libzip-dev \
	&& docker-php-ext-configure gd --with-jpeg --with-webp \
	&& docker-php-ext-install gd zip redis \
	&& runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	&& apk add --virtual .wordpress-phpexts-rundeps $runDeps \
	&& apk del .build-deps \
	&& docker-php-source delete \
	# ----------
	# 2. wp-cli tool
	# ----------
	&& curl -L -o /tmp/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	&& chmod +x /tmp/wp-cli.phar \
	&& mv /tmp/wp-cli.phar /usr/local/bin/wp \
	# ----------
	# ~. upgrade/clean up
	# ----------
	&& apk upgrade \
	&& rm -rf /var/cache/apk/* \
	&& rm -rf /tmp/*
# ====================
# Unison and rsync tool
# ====================
	RUN set -ex \
	&& echo "Installing Unison." \
	&& apk add --no-cache inotify-tools \
	&& apk add --no-cache coreutils \
	&& apk add --no-cache rsync \
	&& apk add --no-cache --virtual .unison-build-deps \
		make \
		ocaml \
		musl-dev \
	&& cd /tmp \
    && wget -O unison-$UNISON_VERSION.tar.gz https://github.com/bcpierce00/unison/archive/$UNISON_VERSION.tar.gz \
	&& tar -xzvf unison-$UNISON_VERSION.tar.gz \
    && rm unison-$UNISON_VERSION.tar.gz \
    && cd unison-$UNISON_VERSION \
    && make \
	&& cp ./src/unison /usr/local/bin \
	&& cp ./src/unison-fsmonitor /usr/local/bin \
    && cd /tmp \
    && rm -rf unison-$UNISON_VERSION \
	&& mkdir -p $UNISON \
	&& mkdir -p $UNISON_LOG_DIR \
	&& apk del .unison-build-deps

	 
# ssh
COPY sshd_config /etc/ssh/ 
# php
COPY php.ini /usr/local/etc/php/php.ini
COPY php_conf/. /usr/local/etc/php/conf.d/
COPY php_fpm_conf/. /usr/local/etc/php-fpm.d/
COPY php-fpm.conf /usr/local/etc/
# nginx
COPY nginx_conf/nginx.conf /etc/nginx/nginx.conf
COPY nginx_conf/wordpress-server.conf /etc/nginx/conf.d/default.conf
COPY nginx_conf/spec-settings.conf /etc/nginx/conf.d/spec-settings.conf
COPY nginx_conf/wordpress-server.conf /usr/src/nginx/wordpress-server.conf
COPY nginx_conf/wordpress-phpmyadmin-server.conf /usr/src/nginx/wordpress-phpmyadmin-server.conf
COPY nginx_conf/wordpress-subdirectory-multisite-server.conf /usr/src/nginx/wordpress-subdirectory-multisite-server.conf
COPY nginx_conf/wordpress-subdirectory-multisite-phpmyadmin-server.conf /usr/src/nginx/wordpress-subdirectory-multisite-phpmyadmin-server.conf
COPY nginx_conf/wordpress-subdomain-afd-multisite-server.conf /usr/src/nginx/wordpress-subdomain-afd-multisite-server.conf
COPY nginx_conf/wordpress-subdomain-afd-multisite-phpmyadmin-server.conf /usr/src/nginx/wordpress-subdomain-afd-multisite-phpmyadmin-server.conf
COPY nginx_conf/temp-server-installation.conf /usr/src/nginx/temp-server-installation.conf
COPY nginx_conf/temp-server-maintenance.conf /usr/src/nginx/temp-server-maintenance.conf
# phpmyadmin
COPY phpmyadmin_src/. $PHPMYADMIN_SOURCE/
# log rotater
COPY logrotate.conf /etc/logrotate.conf
RUN chmod 444 /etc/logrotate.conf
COPY logrotate.d/. /etc/logrotate.d/
RUN chmod -R 444 /etc/logrotate.d
# supervisor
COPY supervisord-original.conf /etc/supervisord.conf
COPY supervisord-original.conf /usr/src/supervisor/
COPY supervisord-stgoptmzd.conf /usr/src/supervisor/
# wordpress
COPY wordpress_src/. $WORDPRESS_SOURCE/
# lsync config
COPY lsyncd.conf /etc/lsyncd/lsyncd.conf
#temporary server
COPY temp_server_src/. /usr/src/temp-server/
# php
COPY uploads.ini /usr/local/etc/php/conf.d/


# =====
# final
# =====
COPY local_bin/. /usr/local/bin/
RUN chmod -R +x /usr/local/bin
EXPOSE $SSH_PORT 80
EXPOSE 2222 80
ENTRYPOINT ["entrypoint.sh"]
