# README

这个 repo 提供了一个开箱即用的梯子部署方案。你只需要有一个域名和一个 VPS，就可以使用脚本通过 Docker 容器化部署 V2Ray(v5.14.1) 和 OpenVPN(v2.6.12) 服务。

## 组件

* [v2ray](https://github.com/v2fly/v2ray-core): V2Ray 代理服务 + DNS
* [swag](https://github.com/linuxserver/docker-swag): Web 服务器 + 自动提供 Letsencrypt 证书
* [haproxy](https://github.com/haproxy/haproxy): TCP/UDP 路由
* [ocserv](https://ocserv.gitlab.io/www/index.html): 兼容 Cisco Anyconnect 协议的 OpenConnect VPN
* [cloudflare-warp](https://developers.cloudflare.com/warp-client/get-started/linux/): Cloudflare 提供的 socks5 代理
* [openvpn howto](https://openvpn.net/community-resources/how-to/): OpenVPN HowTo
* [openvpn ref](https://openvpn.net/community-resources/reference-manual-for-openvpn-2-4/): OpenVPN Manual

## 要求

* 512MB RAM
* Ubuntu, Debian, Arch, Fedora, CentOS
* 拥有一个域名，并解析到自己 VPS 的 IP
* 确保 VPS 的 80 和 443 端口是开放的

## 用法

### 安装

```shell
# 下载脚本
wget https://raw.githubusercontent.com/PandaRyshan/ladder/main/setup.sh

# 给脚本执行权限
chmod +x setup.sh

# 运行脚本
./setup.sh
```

### 新建 OpenVPN 用户并下载客户端配置

```shell
# 默认会把配置安装在 ladder 文件夹

cd ladder

# 把 <username> 替换为你想要的用户名
docker exec openvpn /build-client.sh <username>

# 把配置文件复制到 web 资源目录，之后可以访问 你的域名/client-<username>.ovpn 来下载客户端配置文件
cp ./config/openvpn/client/client-<username>.ovpn ./config/www/
```

## 问题

1. 怎么配置 cloudflare warp

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
* [ ] add help
* [x] deploy via script
* [x] upgrade via script
* [x] remove via script
