ARG BUILD_FROM
FROM $BUILD_FROM

# Use upstream image as-is. Do not override its Entrypoint — the upstream
# image already provides the `nebula-sync` binary and entry behaviour.
# This keeps the image identical to the upstream image and avoids issues
# with non-root build users when running build-time commands.

WORKDIR /config
