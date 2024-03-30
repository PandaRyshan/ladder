# README

这个 repo 提供了一个开箱即用的梯子部署方案。你只需要有一个域名和一个 VPS，就可以使用脚本通过 Docker 容器化部署 V2Ray(v5.12.1) 和 OpenConnect(v1.2.4) 服务。

> 当前只提供了 V2Ray 和 OpenConnect 一起部署的功能，并在 Ubuntu 22.04 测试通过
>
> 升级和卸载功能尚未测试

## 组件

* [v2ray](https://github.com/v2fly/v2ray-core): V2Ray 代理服务 + DNS
* [swag](https://github.com/linuxserver/docker-swag): Web 服务器 + 自动提供 Letsencrypt 证书
* [haproxy](https://github.com/haproxy/haproxy): TCP/UDP 路由
* [ocserv](https://ocserv.gitlab.io/www/index.html): 兼容 Cisco Anyconnect 协议的 OpenConnect VPN
* [cloudflare-warp](https://developers.cloudflare.com/warp-client/get-started/linux/): Cloudflare 提供的 socks5 代理

## 要求

* 600MB 以上 RAM
* 系统升级至最新
* 配置好域名解析
* 确保 80 和 443 端口是开放的

## 用法

```shell
# 下载脚本
wget https://raw.githubusercontent.com/PandaRyshan/ladder/main/setup.sh

# 给脚本执行权限
chmod +x setup.sh

# 运行脚本
./setup.sh
```

根据提示输入域名和邮箱（用于证书更新失败时的通知）。脚本提供的默认部署方式要用到子域名，主域名和子域名要分开写，如 `subdomain.example.com`，主域名部分是 `example.com`，子域名为 `subdomain`。请提前在 DNS 中设置好 V2Ray 和 OpenConnect 要使用的子域名解析，并确保 VPS 的 80 和 443 端口是放开且未占用的。

如果遇到服务已经完全启动，但无法连通的情况，重启一下容器就好了

```shell
docker compose restart
```

如果你想通过 swag 来申请更多证书，可以在 docker-compose.yml 中使用 EXTRA_DOMAINS 参数, see 'Parameters' in swag [README](https://github.com/linuxserver/docker-swag).

## 问题

1. 脚本启动后容器状态正常，但不能连不上

   需要重启一下 HAProxy，原因还在调查

   ```shell
   docker compose restart haproxy_tcp haproxy_http
   ```

2. 几个容器反复重启

    这种情况很有可能是因为证书申请失败，v2ray 和 openconnect 都需要配置证书才能运行。可以检查 ladder/config/certs/live 路径下的证书是否存在或完整。如果确认证书申请失败，可以通过重启 swag 容器让 swag 自动重新申请证书试试看。因此最好等自己的域名解析设置完成后，并确保 80 和 443 端口是开放且未被占用的状态。

    ```shell
    docker compose restart
    ```

3. 怎么配置 cloudflare warp

   cloudflare warp 本身无需配置，只需在 config/v2ray/config.json 中的 warp 模块中，配置需要转发到 warp 的规则即可，v2ray 的规则编写可以参考 v2ray 文档

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
* [x] upgrade via script
* [ ] remove via script
