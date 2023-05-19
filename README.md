# README

This repo is aimed at helping users to easily deploy a new proxy or VPN environment or update the exists environment.

## Components

* [v2ray](https://github.com/v2fly/v2ray-core): proxy server
* [swag](https://github.com/linuxserver/docker-swag): nginx + certbot, request certs and process web requests
* [haproxy](https://github.com/haproxy/haproxy): tcp requests router
* [cloudflare-warp](https://developers.cloudflare.com/warp-client/get-started/linux/): socks5 proxy provided by cloudflare
* [ocserv](https://ocserv.gitlab.io/www/index.html): a vpn server compatible with cisco anyconnect

## Usage

Use `git clone https://github.com/PandaRyshan/ladder.git && cd ladder` command clone this repo and `cd` into it, then run `./setup.sh`. It will install docker environment, install docker-compose-plugin, prepare the config files, and start all the containers automatically.

> Currently this script only support install whole thing.

Or

1. register a domain name and bind your server ip in the DNS settings
2. install docker, docker-compose-plugin(v2), see: [Install Guide](https://docs.docker.com/engine/install/)
3. `git clone https://github.com/PandaRyshan/ladder.git && cd ladder`
4. run `cp .env-sample .env` and replace your domain and email into the spaces
5. run `cp` copy the v2ray/haproxy/ocserv config smaple files as real config files, and replace your domain into them
6. run `docker compose up -d`

## Reference

* [guide.v2fly.org](https://guide.v2fly.org/advanced/quic.html)
* [v2fly.org](https://www.v2fly.org/v5/config/inbound.html)
* [v2ray.com](https://www.v2ray.com/chapter_02/policy.html)
* [haproxy manual](https://docs.haproxy.org/dev/configuration.html)
* [haproxy.com](https://www.haproxy.com/documentation/hapee/latest/load-balancing/protocols/http-2/)
* [ocserv manual](https://ocserv.gitlab.io/www/manual.html)
* [科学上网 | 左耳朵耗子](https://haoel.github.io/#94-cloudflare-warp-%E5%8E%9F%E7%94%9F-ip)

## Todo

* [x] add script to download expanded geoip and geosite data
* [x] replace host and domain into config
* [x] fix ocserv connection via haproxy
* [ ] check if docker service exists
* [ ] use script to deploy automatically
  * [x] deploy v2ray and ocserv
  * [ ] deploy v2ray only
  * [ ] deploy ocserv only
  * [ ] upgrade containers
  * [ ] remove containers
  * [ ] add docker binary checker or ask if need to install docker
  * [ ] add docker image pull command to ensure the images are up to date
