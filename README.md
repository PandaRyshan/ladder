# README

For deploy v2ray proxy easier.

## Components

* [v2ray](https://github.com/v2fly/v2ray-core): proxy
* [swag](https://github.com/linuxserver/docker-swag): request and renew letsencrypt certs, render webpage
* [haproxy](https://github.com/haproxy/haproxy): split web/proxy volume
* [cloudflare-warp](https://developers.cloudflare.com/warp-client/get-started/linux/): socks5 proxy provided by cloudflare for some speciall cases

## Todo

* [ ] replace host ip into v2ray config.json
