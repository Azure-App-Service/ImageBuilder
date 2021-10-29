FROM BASE_IMAGE_NAME_PLACEHOLDER
LABEL maintainer="Azure App Services Container Images <appsvc-images@microsoft.com>"

ENV PHP_VERSION VERSION_PLACEHOLDER

RUN apt-get update \
   && apt-get install --yes --no-install-recommends \
      curl \
      net-tools \
      dnsutils \
      tcpdump \
      iproute2 \
      nano

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

RUN sed -i 's!ErrorLog ${APACHE_LOG_DIR}/error.log!ErrorLog /dev/stderr!g' /etc/apache2/apache2.conf 
RUN sed -i 's!User ${APACHE_RUN_USER}!User www-data!g' /etc/apache2/apache2.conf 
RUN sed -i 's!User ${APACHE_RUN_GROUP}!Group www-data!g' /etc/apache2/apache2.conf 
RUN { \
   echo 'DocumentRoot /home/site/wwwroot'; \
   echo 'DirectoryIndex default.htm default.html index.htm index.html index.php hostingstart.html'; \
   echo 'CustomLog /dev/null combined'; \
   echo '<FilesMatch "\.(?i:ph([[p]?[0-9]*|tm[l]?))$">'; \
   echo '   SetHandler application/x-httpd-php'; \
   echo '</FilesMatch>'; \
   echo '<DirectoryMatch "^/.*/\.git/">'; \
   echo '   Order deny,allow'; \
   echo '   Deny from all'; \
   echo '</DirectoryMatch>'; \
   echo 'EnableMMAP Off'; \
   echo 'EnableSendfile Off'; \
} >> /etc/apache2/apache2.conf

RUN rm -f /usr/local/etc/php/conf.d/php.ini \
   && { \
                echo 'error_log=/dev/stderr'; \
                echo 'display_errors=Off'; \
                echo 'log_errors=On'; \
                echo 'display_startup_errors=Off'; \
                echo 'date.timezone=UTC'; \
                echo 'zend_extension=opcache'; \
    } > /usr/local/etc/php/conf.d/php.ini

RUN rm -f /etc/apache2/conf-enabled/other-vhosts-access-log.conf
RUN rm /etc/apache2/sites-enabled/000-default.conf

COPY mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf

WORKDIR /home/site/wwwroot

ENTRYPOINT ["/bin/init_container.sh"]
