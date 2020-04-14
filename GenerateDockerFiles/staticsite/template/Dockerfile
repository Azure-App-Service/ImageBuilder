FROM nginx
LABEL maintainer="Azure App Services Container Images <appsvc-images@microsoft.com>"

RUN mkdir -p /home/LogFiles /opt/startup \
     && echo "root:Docker!" | chpasswd \
     && echo "cd /home" >> /etc/bash.bashrc \
     && apt-get update \  
     && apt-get install --yes --no-install-recommends \
      openssh-server \
      vim \
      curl \
      wget \
      tcptraceroute \
      openrc \
      yarn \
      net-tools \
      dnsutils \
      tcpdump \
      iproute2

# setup default site
RUN rm -f /etc/ssh/sshd_config
COPY startup /opt/startup

# setup SSH
COPY sshd_config /etc/ssh/
RUN mkdir -p /home/LogFiles \
     && echo "root:Docker!" | chpasswd \
     && echo "cd /home" >> /root/.bashrc 

RUN mkdir -p /var/run/sshd

RUN chmod -R +x /opt/startup

ENV PORT 8080
ENV SSH_PORT 2222
EXPOSE 2222 8080

ENV WEBSITE_ROLE_INSTANCE_ID localRoleInstance
ENV WEBSITE_INSTANCE_ID localInstance
ENV PATH ${PATH}:/home/site/wwwroot

WORKDIR /home/site/wwwroot

COPY mysite /etc/nginx/sites-available/mysite
COPY nginx.conf /etc/nginx/nginx.conf
RUN mkdir /etc/nginx/sites-enabled

ENTRYPOINT ["/opt/startup/init_container.sh"]
