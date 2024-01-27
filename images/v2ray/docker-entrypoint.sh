#!/bin/sh

v2ray run -config /etc/v2ray/config.json &

socat TCP-LISTEN:7890,reuseaddr,fork TCP:127.0.0.1:10808
