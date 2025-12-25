ARG BUILD_FROM
FROM $BUILD_FROM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Use upstream image as-is. Many upstream images are minimal/non-debian
# and do not support package manager operations during a build step.
# Therefore avoid running apt/dnf inside the image; just copy the wrapper
# and exec the upstream binary or passed command.

COPY --chmod=0755 run.sh /run.sh

WORKDIR /config

CMD ["/run.sh"]
