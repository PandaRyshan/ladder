# README

这个 repo 提供了一个开箱即用的梯子部署方案。你只需要有一个域名和一个 VPS，就可以使用脚本通过 Docker 容器化部署 V2Ray 和 OpenConnect 服务。

## 组件

* [v2ray](https://github.com/v2fly/v2ray-core): V2Ray 代理服务 + DNS
* [swag](https://github.com/linuxserver/docker-swag): Web 服务器 + 自动提供 Letsencrypt 证书
* [haproxy](https://github.com/haproxy/haproxy): TCP 路由
* [cloudflare-warp](https://developers.cloudflare.com/warp-client/get-started/linux/): Cloudflare 提供的 socks5 代理
* [ocserv](https://ocserv.gitlab.io/www/index.html): 兼容 Cisco Anyconnect 协议的 OpenConnect VPN

## 配置要求

* 1核 CPU
* 500MB 运行内存

## 用法

### 选项 1

使用自动部署脚本：

```shell
wget https://github.com/PandaRyshan/ladder/raw/master/setup.sh
chmod +x setup.sh
./setup.sh
```

Then input your information into it, and wait until script finished.

### 选项 2

1. 安装 docker, docker-compose-plugin(v2), see: [Install Guide](https://docs.docker.com/engine/install/)

2. 克隆这个 repo

   ```shell
   git clone https://github.com/PandaRyshan/ladder.git && cd ladder
   ```

3. 创建你自己的 docker compose 配置文件，并完善其中的信息

    ```shell
    cp docker-compose.yml.sample docker-compose.yml
    ```

4. 创建你自己的 docker compose 环境文件，并完善其中的信息

    ```shell
    cp .env.sample .env
    ```

5. 创建你自己的 v2ray/haproxy/ocserv 配置文件, 并完善其中的信息

    ```shell
    cp config/v2ray/config.json.sample config/v2ray/config.json
    cp config/ocserv/ocserv.conf.sample config/ocserv/ocserv.conf
    cp config/haproxy/haproxy.cfg.sample config/haproxy/haproxy.cfg
    ```

6. 启动容器

    ```shell
    docker compose up -d
    ```

如果你想通过 swag 来申请更多证书，可以在 docker-compose.yml 中使用 EXTRA_DOMAINS 参数, see 'Parameters' in swag [README](https://github.com/linuxserver/docker-swag).

## 参考

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
* [ ] upgrade via script
* [ ] remove via script
