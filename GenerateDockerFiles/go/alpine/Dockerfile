FROM alpine:3.14
LABEL maintainer="Azure App Services Container Images <appsvc-images@microsoft.com>"

# Web Site Home
ENV HOME_SITE "/home/site/wwwroot"
ENV APP_PATH "/home/site/wwwroot"

# Setup SSH and activate virtual env on ssh into containers
# NOTE: dnsutils is not available in apk
# NOTE: libc6-compat is needed for Go
RUN mkdir -p /home/LogFiles /opt/startup \
     && echo "root:Docker!" | chpasswd \
     && echo "cd /home" >> /etc/bash.bashrc \
     && apk update \  
     && apk upgrade \  
     && apk add --update --no-cache bash \
      openssh \
      file \
      vim \
      curl \
      wget \
      tcptraceroute \
      openrc \
      net-tools \
      tcpdump \
      iproute2 \
      nano \
      libc6-compat \
     && chmod -R 777 /opt/startup

# Setup default site
RUN rm -f /etc/ssh/sshd_config
COPY init_container.sh /opt/startup
COPY hostingstart.html /opt/startup
COPY hostingstart /opt/startup

# Configure startup
RUN mkdir -p /tmp
COPY sshd_config /etc/ssh/

COPY ssh_setup.sh /tmp
RUN chmod -R +x /opt/startup \
   && chmod -R +x /tmp/ssh_setup.sh \
   && (sleep 1;/tmp/ssh_setup.sh 2>&1 > /dev/null) \
   && rm -rf /tmp/* \
   && echo "cd /home" >> /root/.bashrc \
   && cd /opt/startup \
   && chmod +x /opt/startup/hostingstart

ENV PORT 8080
ENV SSH_PORT 2222
EXPOSE 2222 8080

ENV WEBSITE_ROLE_INSTANCE_ID localRoleInstance
ENV WEBSITE_INSTANCE_ID localInstance
ENV PATH ${PATH}:"/home/site/wwwroot"

WORKDIR ${HOME_SITE}

ENTRYPOINT ["/opt/startup/init_container.sh"]
