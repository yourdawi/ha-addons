ARG BUILD_FROM
FROM $BUILD_FROM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    unzip \
    bash \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/spotconnect

COPY run.sh /
RUN chmod a+x /run.sh

WORKDIR /config

CMD ["/run.sh"]