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
COPY hostingstart.html /opt/startup

# configure startup
RUN mkdir -p /tmp
COPY sshd_config /etc/ssh/

# ssh setup
COPY ssh_setup.sh /tmp
RUN chmod -R +x /opt/startup \
   && chmod -R +x /tmp/ssh_setup.sh \
   && (sleep 1;/tmp/ssh_setup.sh 2>&1 > /dev/null) \
   && rm -rf /tmp/* \
   && echo "cd /home" >> /root/.bashrc
#    && cd /opt/startup \
#    && npm install 

# RUN chmod -R +x /opt/startup

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

COPY hostingstart.html /home/site/wwwroot/index.html

ENTRYPOINT ["/opt/startup/init_container.sh"]

# # setup nginx
# COPY mysite /etc/nginx/sites-available
# RUN ln -s /etc/nginx/sites-available/mysite /etc/nginx/sites-enabled/mysite