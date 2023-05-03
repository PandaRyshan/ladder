# README

For deploy v2ray proxy easier.

## Components

* [v2ray](https://github.com/v2fly/v2ray-core): proxy
* [swag](https://github.com/linuxserver/docker-swag): request and renew letsencrypt certs, render webpage
* [haproxy](https://github.com/haproxy/haproxy): split web/proxy volume
* [cloudflare-warp](https://developers.cloudflare.com/warp-client/get-started/linux/): socks5 proxy provided by cloudflare for some speciall cases

## Usage

1. register a domain name and bind your server ip in the DNS settings
2. install docker, docker-compose-plugin(v2) or docker-compose(v1), see: [Install Guide](https://docs.docker.com/engine/install/)
3. git clone this repo and enter the dir
4. run `cp .env-sample .env` and replace your domain and email into the spaces
5. run `sh pre-config.sh`
6. run `docker-compose up -d` or `docker compose up -d`

## Reference

* [guide.v2fly.org](https://guide.v2fly.org/advanced/quic.html)
* [v2fly.org](https://www.v2fly.org/v5/config/inbound.html)
* [v2ray.com](https://www.v2ray.com/chapter_02/policy.html)
* [haproxy manual](https://docs.haproxy.org/dev/configuration.html)
* [haproxy.com](https://www.haproxy.com/documentation/hapee/latest/load-balancing/protocols/http-2/)
* [科学上网 | 左耳朵耗子](https://haoel.github.io/#94-cloudflare-warp-%E5%8E%9F%E7%94%9F-ip)

## Todo

* [ ] replace host and domain into config
* [x] add script to download expanded geoip and geosite dat