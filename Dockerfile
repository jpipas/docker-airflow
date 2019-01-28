# VERSION 1.10.2
# AUTHOR: Jeff Pipas
# DESCRIPTION: Basic Airflow container
# BUILD: docker build --rm -t jpipas/docker-airflow .
# SOURCE: https://github.com/jpipas/docker-airflow

FROM python:3.6-slim
LABEL maintainer="jpipas"

# Never prompts the user for choices on installation/configuration of packages
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

# Airflow
ARG AIRFLOW_VERSION=1.10.2
ARG AIRFLOW_HOME=/usr/local/airflow
ARG AIRFLOW_DEPS=""
ARG PYTHON_DEPS=""
ENV AIRFLOW_GPL_UNIDECODE yes
ENV AIRFLOW__SCHEDULER__MIN_FILE_PROCESS_INTERVAL=60
ENV AIRFLOW__SCHEDULER__SCHEDULER_MAX_THREADS=1
ENV AIRFLOW__WEBSERVER__WORKERS=2
ENV AIRFLOW__WEBSERVER__WORKER_REFRESH_INTERVAL=1800
ENV AIRFLOW__WEBSERVER__WEB_SERVER_WORKER_TIMEOUT=300
ENV AIRFLOW_HOME=${AIRFLOW_HOME}
# Define en_US.
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8

RUN set -ex \
    && buildDeps=' \
        freetds-dev \
        python3-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        libpq-dev \
        git \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        freetds-bin \
        build-essential \
        python3-pip \
        python3-requests \
        default-libmysqlclient-dev \
        apt-utils \
        curl \
        rsync \
        netcat \
        locales \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && useradd -ms /bin/bash -d ${AIRFLOW_HOME} airflow \
    && pip install -U pip setuptools wheel \
    && pip install pytz \
    && pip install pyOpenSSL \
    && pip install ndg-httpsclient \
    && pip install pyasn1 \
    && pip install pymssql==2.1.1 \
    && pip install flask-appbuilder==1.11.1 \
    && pip install apache-airflow[crypto,celery,postgres,mssql,s3,hive,jdbc,mysql,ssh${AIRFLOW_DEPS:+,}${AIRFLOW_DEPS}]==${AIRFLOW_VERSION} \
    && pip install 'celery[redis]>=4.1.1,<4.2.0' \
    && pip install 'redis>=2.10.5, <3.0.0' \
    && if [ -n "${PYTHON_DEPS}" ]; then pip install ${PYTHON_DEPS}; fi \
    && apt-get purge --auto-remove -yqq $buildDeps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

COPY script/entrypoint.sh /entrypoint.sh
COPY config/airflow.cfg ${AIRFLOW_HOME}/airflow.cfg

RUN chown -R airflow: ${AIRFLOW_HOME}

# This fixes high CPU load in airflow 1.10
COPY config/af_1.10_high_cpu.patch /root/af_1.10_high_cpu.patch
RUN patch -d /usr/local/lib/python3.6/site-packages/airflow/ < /root/af_1.10_high_cpu.patch; \
    rm /root/af_1.10_high_cpu.patch

EXPOSE 8080 5555 8793

USER airflow
WORKDIR ${AIRFLOW_HOME}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["webserver"] # set default arg for entrypoint
