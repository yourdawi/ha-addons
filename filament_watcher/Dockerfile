ARG BUILD_FROM
FROM $BUILD_FROM

# Install Python and dependencies
RUN apk add --no-cache python3 py3-pip py3-requests py3-beautifulsoup4

# Install paho-mqtt via pip
RUN pip3 install --no-cache-dir --break-system-packages paho-mqtt

# Copy application files
WORKDIR /app
COPY main.py .
COPY config.json .
COPY run.sh /

# Make run script executable
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
