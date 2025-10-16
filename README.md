# README

容器化快速部署 v2ray shadowsocks-rust openvpn warp 等服务，使用 haproxy 作为 tcp 路由，nginx 作为 http 路由，内置 certbot 自动申请证书，以实现代理和 web 服务共享端口。

ss 和 openvpn 共享 443 端口的意义不大，如果需要，可以停止使用 haproxy 的 tls 终止，并根据 sni 特征分流即可。

## 要求

* 512MB RAM
* Ubuntu / Debian / Arch / Fedora / CentOS
* 拥有一个域名，并解析到服务器 IP
* 确保 VPS 的 80 和 443 端口是开放的

## 用法

### 安装

```shell
curl -fsSL https://raw.githubusercontent.com/PandaRyshan/ladder/main/setup.sh | bash
```

### 查看 V2Ray 配置

V2Ray 配置在 ladder 目录下的 info.txt 内。

### v2ray 转发配置示例

增加 rules 规则，按 `inboundTag` 拦截所有请求并转发，例如：

```json
"outbounds": [
   {
      "tag": "my-remote-server",
      "protocol": "vmess",
      "settings": {
         "vnext": [
            "address": "my-remote-server.com",
            "port": 443,
            "users": [{"xxxxxx-xxxxxx-xxxxxx-xxxxxx"}]
         ]
      },
      "streamSettings": {
         "network": "tcp",
         "security": "tls"
      }
   }
]
"routing": {
   "rules": [
      {
         "type": "field",
         "inboundTag": ["tcp"]
         "outboundTag": "my-remote-server"
      }
   ]
}
```

### 管理

setup.sh 脚本中包含简单的管理功能，可以根据编号使用相应功能。

## 组件

* [V2Ray](https://github.com/v2fly/v2ray-core): V2Ray 代理服务 + DNS
* [HAProxy](https://github.com/haproxy/haproxy): TCP 路由
* [SWAG](https://github.com/linuxserver/docker-swag): HTTP 路由 + Web + CertBot
* [Cloudflare-WARP](https://developers.cloudflare.com/warp-client/get-started/linux/): Cloudflare 提供的 socks5 代理
* [OpenVPN](https://community.openvpn.net/openvpn/wiki/Downloads)：安全加密方式的 VPN

## 参考

* [guide.v2fly.org](https://guide.v2fly.org/advanced/quic.html)
* [v2fly.org](https://www.v2fly.org/v5/config/inbound.html)
* [v2ray.com](https://www.v2ray.com/chapter_02/policy.html)
* [haproxy manual](https://docs.haproxy.org/dev/configuration.html)
* [haproxy.com](https://www.haproxy.com/documentation/hapee/latest/load-balancing/protocols/http-2/)
* [ocserv manual](https://ocserv.gitlab.io/www/manual.html)
* [openvpn howto](https://openvpn.net/community-resources/how-to/)
* [openvpn ref](https://openvpn.net/community-resources/reference-manual-for-openvpn-2-4/)
* [科学上网 | 左耳朵耗子](https://haoel.github.io/#94-cloudflare-warp-%E5%8E%9F%E7%94%9F-ip)

## Todo

* [ ] add quic support for haproxy
* [ ] add help
