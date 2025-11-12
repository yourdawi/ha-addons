ARG BUILD_FROM=pihole/pihole:latest
FROM $BUILD_FROM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Upstream Pi-hole image already contains needed services. We add bashio + helper tooling if missing.
ENV DEBIAN_FRONTEND=noninteractive

COPY run.sh /run.sh
RUN chmod a+x /run.sh

WORKDIR /config

ENTRYPOINT ["/run.sh"]
