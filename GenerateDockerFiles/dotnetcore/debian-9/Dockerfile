FROM BASE_IMAGE_NAME_PLACEHOLDER
LABEL maintainer="Azure App Services Container Images <appsvc-images@microsoft.com>"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-utils \
        unzip \
        openssh-server \
        vim \
        curl \
        wget \
        tcptraceroute \
        net-tools \
        dnsutils \
        tcpdump \
        iproute2 \
        nano \
        cron \
    && apt-get upgrade -y openssl \
    && rm -rf /var/lib/apt/lists/*

COPY tcpping /usr/bin/tcpping
RUN chmod 755 /usr/bin/tcpping

RUN curl -L https://aka.ms/downloadazcopy-v10-linux | tar -C /usr/local/bin -xzf - --strip-components=1

RUN mkdir -p /defaulthome/hostingstart \
    && mkdir -p /home/LogFiles/ \
    && echo "root:Docker!" | chpasswd \
    && echo "cd /home" >> /root/.bashrc

COPY bin.zip /tmp
RUN unzip -q -o /tmp/bin.zip -d /defaulthome/hostingstart \
    && rm /tmp/bin.zip

COPY init_container.sh /bin/
RUN chmod 755 /bin/init_container.sh

COPY hostingstart.html /defaulthome/hostingstart/wwwroot/

# configure startup
COPY sshd_config /etc/ssh/
COPY ssh_setup.sh /tmp
RUN mkdir -p /opt/startup \
   && chmod -R +x /opt/startup \
   && chmod -R +x /tmp/ssh_setup.sh \
   && (sleep 1;/tmp/ssh_setup.sh 2>&1 > /dev/null) \
   && rm -rf /tmp/*

COPY dotnet_monitor_config.json /dotnet_monitor_config.json
COPY run-dotnet-monitor.sh /run-dotnet-monitor.sh
RUN chmod +x /run-dotnet-monitor.sh

COPY run-diag.sh /run-diag.sh
RUN chmod +x /run-diag.sh

ENV PORT 8080
ENV SSH_PORT 2222
EXPOSE 8080 2222 50050

ENV WEBSITE_ROLE_INSTANCE_ID localRoleInstance
ENV WEBSITE_INSTANCE_ID localInstance
ENV PATH ${PATH}:/home/site/wwwroot
ENV ASPNETCORE_URLS=
ENV ASPNETCORE_FORWARDEDHEADERS_ENABLED=true
ENV HOME /home

# Enable automatic creation of dumps when a process crashes
ENV COMPlus_DbgEnableMiniDump="1"
# Create a base directory for dumps under /home so that the
# dumps are accessible from the build container too (since a runtime container might have already crashed)
ENV DUMP_DIR="/home/logs/dumps"
RUN mkdir -p "$DUMP_DIR"
RUN chmod 777 "$DUMP_DIR"

WORKDIR /home/site/wwwroot

ENTRYPOINT ["/bin/init_container.sh"]
