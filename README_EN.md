# README

This repository is designed to offer a almost out-of-the-box Docker environment for deploying a proxy service. It includes an automated bash script that simplifies the process of fresh deployments, updates, and uninstallations. All you need is a domain name and a VPS, and you can start using these services conveniently and securely.

## Components

* [v2ray](https://github.com/v2fly/v2ray-core): proxy server + dns
* [swag](https://github.com/linuxserver/docker-swag): nginx + certbot, request certs and process web requests
* [haproxy](https://github.com/haproxy/haproxy): tcp requests router
* [ocserv](https://ocserv.gitlab.io/www/index.html): a vpn server compatible with cisco anyconnect
* [cloudflare-warp](https://developers.cloudflare.com/warp-client/get-started/linux/): socks5 proxy provided by cloudflare

## Requirements

* 600MB RAM
* upgrade your os to latest
* make sure your 80 and 443 port is open

## Usage

There's a script that you can deploy these containers automatically.

```shell
wget https://raw.githubusercontent.com/PandaRyshan/ladder/main/setup.sh
chmod +x setup.sh
./setup.sh
```

Then input your information into it, and wait until script finished.

If you found that you cannot connect to the server after all containers are ready, you could try restart all of them.

```shell
docker compose restart
```

If you want to request certificates for other domains at the same time, you can use EXTRA_DOMAINS in swag's environment, see 'Parameters' in swag [README](https://github.com/linuxserver/docker-swag).

## Known Issues

1. All containers status are ready, but I can't connect to my server

   Basiclly this will only happen after your first deploy. Sometimes you need to restart HAProxy. I'm still digging the reason.

   ```shell
   docker compose restart haproxy_tcp haproxy_http
   ```

2. Why cloudflare warp is not start

   Previously the warp image I used have some problems and will cause the used storage explode. This component will be back after I build my own image.

3. How to set up cloud warp

   No need to configuration, just fill your rules in the config/v2ray/config.json

## Reference

* [guide.v2fly.org](https://guide.v2fly.org/advanced/quic.html)
* [v2fly.org](https://www.v2fly.org/v5/config/inbound.html)
* [v2ray.com](https://www.v2ray.com/chapter_02/policy.html)
* [haproxy manual](https://docs.haproxy.org/dev/configuration.html)
* [haproxy.com](https://www.haproxy.com/documentation/hapee/latest/load-balancing/protocols/http-2/)
* [ocserv manual](https://ocserv.gitlab.io/www/manual.html)
* [科学上网 | 左耳朵耗子](https://haoel.github.io/#94-cloudflare-warp-%E5%8E%9F%E7%94%9F-ip)

## Todo

* [x] add menu
* [x] add help
* [ ] deploy via script
  * [x] deploy v2ray + ocserv
  * [ ] deploy v2ray only
  * [ ] deploy ocserv only
* [x] upgrade via script
* [ ] remove via script
