# README

这个 repo 提供了一个开箱即用的梯子部署方案。你只需要有一个域名和一个 VPS，就可以使用脚本通过 Docker 容器化部署 V2Ray(v5.14.1) 和 OpenVPN(v2.6.12) 服务。

## 组件

* [V2Ray](https://github.com/v2fly/v2ray-core): V2Ray 代理服务 + DNS
* [HAProxy](https://github.com/haproxy/haproxy): TCP 路由
* [SWAG](https://github.com/linuxserver/docker-swag): HTTP 路由 + Web + CertBot
* [Cloudflare-WARP](https://developers.cloudflare.com/warp-client/get-started/linux/): Cloudflare 提供的 socks5 代理
* [OpenVPN](https://community.openvpn.net/openvpn/wiki/Downloads)：安全加密方式的 VPN

## 要求

* 512MB RAM
* Ubuntu / Debian / Arch / Fedora / CentOS
* 拥有一个域名，并解析 `prx` 和 `dl` 两个子域名到自己 VPS 的 IP，也可以使用通配符 `*`，如 `*.us.example.com`
* 确保 VPS 的 80 和 443 端口是开放的

## 用法

### 安装

```shell
# 下载脚本
curl -LO https://raw.githubusercontent.com/PandaRyshan/ladder/main/setup.sh

# 给脚本执行权限
chmod +x setup.sh

# 运行脚本
./setup.sh
```

### 查看 V2Ray 配置

V2Ray 配置在 ladder 目录下的 info.txt 内，可以使用 `cat` 命令查看

### 将访问目标通过 v2ray 转发至 warp 访问

修改 v2ray 的配置文件 `config/v2ray/config.json`，找到 `routing` 配置中的 `cf-warp` 项，可以添加希望通过 warp 访问的域名或 IP 地址，例如：

```json
"routing": {
   "rules": [
      {
         "type": "field",
         "outboundTag": "cf-warp",
         "domain": [
            "geosite:openai",
            "example.com"
         ]
      },
      {
         "type": "field",
         "outboundTag": "cf-warp",
         "ip": [
            "geoip:cn",
            "10.10.10.0/24"
         ]
      }
   ]
}
```

### 转发所有请求至其他 v2ray 服务器

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

### 新建用户

使用菜单中的添加用户功能，会自动增加一个 v2ray 客户端 UUID，生成一个 OpenVPN 的客户端证书配置

## 问题

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

* [ ] add help
