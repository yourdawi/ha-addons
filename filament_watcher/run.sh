#!/usr/bin/with-contenv bashio

# Read options from Home Assistant addon config
export MQTT_BROKER=$(bashio::config 'mqtt_broker')
export MQTT_PORT=$(bashio::config 'mqtt_port')
export MQTT_USER=$(bashio::config 'mqtt_user')
export MQTT_PASSWORD=$(bashio::config 'mqtt_password')
export CHECK_INTERVAL=$(bashio::config 'check_interval')

bashio::log.info "Starting Bambulab Filament Watcher..."
bashio::log.info "MQTT Broker: ${MQTT_BROKER}:${MQTT_PORT}"
bashio::log.info "Check Interval: ${CHECK_INTERVAL}s"

exec python3 /app/main.py
