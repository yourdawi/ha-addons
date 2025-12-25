ARG BUILD_FROM
FROM $BUILD_FROM

# Use upstream image as base but run a tiny wrapper to export add-on options
# as environment variables and then exec the upstream binary. We call the
# wrapper via `sh /run.sh` so it works even if the upstream base image
# does not mark the file executable or runs as a non-root user during build.

COPY run.sh /run.sh

WORKDIR /config

ENTRYPOINT ["sh", "/run.sh"]
