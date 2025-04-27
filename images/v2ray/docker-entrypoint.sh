#!/bin/sh

if [ -n "$WAIT_HOSTS" ] || [ -n "$WAIT_PATHS" ]; then
    /wait
fi

if [ -f /etc/v2ray/config.yaml ]; then
    echo "Using config.yaml"
    exec v2ray run -config /etc/v2ray/config.yaml
else
    echo "Using config.json"
    exec v2ray run -config /etc/v2ray/config.json
fi
