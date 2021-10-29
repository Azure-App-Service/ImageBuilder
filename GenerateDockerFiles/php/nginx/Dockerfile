FROM BASE_IMAGE_NAME_PLACEHOLDER
LABEL maintainer="Azure App Services Container Images <appsvc-images@microsoft.com>"

ENV PHP_VERSION VERSION_PLACEHOLDER

RUN apt-get update \
   && apt-get install --yes --no-install-recommends \
      curl \
      net-tools \
      dnsutils \
      tcpdump \
      iproute2

COPY init_container.sh /bin/
COPY hostingstart.html /home/site/wwwroot/hostingstart.html

RUN if [[ "$PHP_VERSION" == "5.6" || "$PHP_VERSION" == "7.0" ]] ; then \
        apt-get install -y libmcrypt-dev \
        && docker-php-ext-install mcrypt; \
    fi

RUN chmod 755 /bin/init_container.sh \
    && mkdir -p /home/LogFiles/ \
    && echo "root:Docker!" | chpasswd \
    && echo "cd /home" >> /root/.bashrc \
    && ln -s /home/site/wwwroot /var/www/html \
    && mkdir -p /opt/startup

# configure startup
COPY sshd_config /etc/ssh/
COPY ssh_setup.sh /tmp
RUN mkdir -p /opt/startup \
   && chmod -R +x /opt/startup \
   && chmod -R +x /tmp/ssh_setup.sh \
   && (sleep 1;/tmp/ssh_setup.sh 2>&1 > /dev/null) \
   && rm -rf /tmp/*

ENV PORT 8080
ENV SSH_PORT 2222
EXPOSE 2222 8080
COPY sshd_config /etc/ssh/

ENV WEBSITE_ROLE_INSTANCE_ID localRoleInstance
ENV WEBSITE_INSTANCE_ID localInstance
ENV PATH ${PATH}:/home/site/wwwroot

RUN sed -i "s/access_log \/var\/log\/nginx\/access.log;/access_log off;/g" /etc/nginx/nginx.conf
RUN sed -i "s/error_log \/var\/log\/nginx\/error.log;/error_log \/dev\/stderr;/g" /etc/nginx/nginx.conf

RUN rm -f /usr/local/etc/php/conf.d/php.ini \
   && { \
                echo 'error_log=/dev/stderr'; \
                echo 'display_errors=Off'; \
                echo 'log_errors=On'; \
                echo 'display_startup_errors=Off'; \
                echo 'date.timezone=UTC'; \
                echo 'zend_extension=opcache'; \
    } > /usr/local/etc/php/conf.d/php.ini

WORKDIR /home/site/wwwroot

ENTRYPOINT ["/bin/init_container.sh"]
