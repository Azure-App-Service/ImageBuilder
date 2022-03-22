FROM BASE_IMAGE_NAME_PLACEHOLDER
LABEL maintainer="appsvc-images@microsoft.com"

# Web Site Home
ENV HOME_SITE "/home/site/wwwroot"
ENV APP_PATH "/home/site/wwwroot"

#Install system dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
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
    && pip install --upgrade pip \
    && pip install subprocess32 \
    && pip install gunicorn \ 
    && pip install virtualenv \
    && pip install flask 

COPY tcpping /usr/bin/tcpping
RUN chmod 755 /usr/bin/tcpping

WORKDIR ${HOME_SITE}

EXPOSE 8000
ENV PORT 8000
ENV SSH_PORT 2222

COPY common/run-diag.sh /run-diag.sh
RUN chmod +x /run-diag.sh

# setup SSH and acitvate virtual env on ssh into container
RUN mkdir -p /home/LogFiles \
     && echo "root:Docker!" | chpasswd \
     && echo "cd /home" >> /root/.bashrc

COPY sshd_config /etc/ssh/
RUN mkdir -p /opt/startup
COPY init_container.sh /opt/startup/init_container.sh

# setup default site
RUN mkdir /opt/defaultsite
COPY hostingstart.html /opt/defaultsite
COPY hostingstart_dep.html /opt/defaultsite
COPY application.py /opt/defaultsite

# gunicorn custom config
COPY gunicorn.conf.py /opt/startup
ENV PYTHON_USE_GUNICORN_CONFIG_FROM_PATH "/opt/startup/gunicorn.conf.py"

# setup appServiceAppLogs 
RUN mkdir -p /opt/startup/app_logs
COPY common/app_logs/ /opt/startup/app_logs/
ENV PYTHONPATH "${PYTHONPATH}:/opt/startup/app_logs"

#code profiler options
RUN mkdir -p /opt/startup/code_profiler
COPY common/code_profiler/code-profiler-not-available.sh /opt/startup/code_profiler/code-profiler-not-available.sh
RUN echo "alias vizviewer=/opt/startup/code_profiler/code-profiler-not-available.sh" >>/root/.bashrc \
    && echo "alias code-profiler=/opt/startup/code_profiler/code-profiler-not-available.sh" >>/root/.bashrc

# configure startup
RUN chmod -R 777 /opt/startup
COPY entrypoint.py /usr/local/bin

ENTRYPOINT ["/opt/startup/init_container.sh"]
