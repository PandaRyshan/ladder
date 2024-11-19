#!/bin/sh

if [[ -n "$WAIT_HOSTS" ]] || [[ -n "$WAIT_PATHS" ]]; then
    /wait
fi

v2ray run -config /etc/v2ray/config.json
