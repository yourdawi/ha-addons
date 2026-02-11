ARG BUILD_FROM
FROM $BUILD_FROM

ARG BFW_REPO=yourdawi/bambulab-filament-watcher
ARG BFW_VERSION=v1.0.0

RUN apk add --no-cache python3 py3-pip curl tar && \
    python3 -m pip install --break-system-packages --no-cache-dir requests beautifulsoup4 paho-mqtt==1.6.1 flask urllib3 waitress

WORKDIR /app

RUN curl -fL "https://codeload.github.com/${BFW_REPO}/tar.gz/refs/tags/${BFW_VERSION}" \
    -o /tmp/bfw-src.tar.gz && \
    mkdir -p /tmp/bfw-src && \
    tar -xzf /tmp/bfw-src.tar.gz -C /tmp/bfw-src --strip-components=1 && \
    cp /tmp/bfw-src/main.py /app/main.py && \
    cp -r /tmp/bfw-src/templates /app/templates && \
    cp -r /tmp/bfw-src/static /app/static && \
    rm -rf /tmp/bfw-src /tmp/bfw-src.tar.gz

CMD ["python3", "/app/main.py"]
