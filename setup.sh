#!/bin/bash

PREVIOUS_MENU=1
MAIN_MENU=1
DEPLOY_MENU=2
INPUT_CONFIG_MENU=3
SYSCTL_MENU=4

main_menu() {
    items=(
        1 "状态 Status" on
        2 "部署 Deploy" off
        3 "重启 Restart" off
        4 "更新 Upgrade" off
        5 "停止 Stop" off
        6 "卸载 Uninstall" off
    )
    while true; do
        choice=$(dialog --clear \
            --title "主菜单" \
            --radiolist "请选择一个选项：" 15 50 5 \
            "${items[@]}" \
            3>&1 1>&2 2>&3)

        # 获取 dialog 退出值
        exit_status=$?
        exit_operation $exit_status

        case $choice in
            1) status_menu ;;
            2)
                deploy_menu
                input_config_menu
                sysctl_menu
                deploy
                break
                ;;
            3) restart_containers ;;
            4) upgrade_containers ;;
            5) stop_containers ;;
            6) down_containers ;;
            *) ;;
        esac
    done
}

status_menu() {
    sudo docker compose ps 2>&1 | dialog --title "容器状态" --programbox 20 70
}

deploy_menu() {
    while true; do
        DEPLOY_CHOICES=$(dialog --clear \
            --title "选择要部署的组件" \
            --extra-button --extra-label "Previous" \
            --checklist "请选择至少一个选项：" 15 50 5 \
            1 "V2Ray" on \
            2 "Warp" off \
            3 "OpenVPN" off \
            4 "SmokePing" off \
            3>&1 1>&2 2>&3)

        exit_status=$?
        exit_operation $exit_status

        if [ -z "$DEPLOY_CHOICES" ]; then
            dialog --msgbox "请至少选择一项" 7 50
        else
            break
        fi
    done
}

input_config_menu() {
    PREVIOUS_MENU=2
    TIMEZONE=${1:-"Asia/Shanghai"}
    DOMAIN=${2:-""}
    WARP_KEY=${3:-""}
    while true; do
        dialog_args=(
            --title "V2Ray 配置" \
            --extra-button --extra-label "Previous" \
            --mixedform "请输入 V2Ray 配置信息：" 15 50 5 \
        )

        # 判断 DEPLOY_CHOICES 中是否包含 Warp 选项，如存在则添加 Warp Key 输入框
        if [[ $DEPLOY_CHOICES == *"2"* ]]; then
            dialog_args+=(
                "时区：" 1 1 "$TIMEZONE" 1 12 30 30 0 \
                "域名：" 2 1 "$DOMAIN" 2 12 30 30 0 \
                "Warp Key：" 3 1 "$WARP_KEY" 3 12 30 30 0)
        else
            dialog_args+=(
                "时区：" 1 1 "$TIMEZONE" 1 8 30 30 0 \
                "域名：" 2 1 "$DOMAIN" 2 8 30 30 0)
        fi

        result=$(dialog "${dialog_args[@]}" 3>&1 1>&2 2>&3)

        exit_status=$?
        exit_operation $exit_status
        # if exit_operation $exit_status; then
        #     break
        # fi

        TIMEZONE=$(sed -n '1p' <<< $result)
        DOMAIN=$(sed -n '2p' <<< $result)
        WARP_KEY=$(sed -n '3p' <<< $result)

        if [ -z "$TIMEZONE" ] || [ -z "$DOMAIN" ]; then
            dialog --msgbox "所有信息均为必填，请继续输入。" 7 50
        else
            break
        fi
    done
}

sysctl_menu() {
    PREVIOUS_MENU=3
    while true; do
        dialog --clear \
            --title "优化 sysctl.conf" \
            --extra-button --extra-label "Previous" \
            --yesno "是否优化 sysctl.conf？" 7 50

        exit_status=$?
        exit_operation $exit_status

        dialog --yesno "确认开始部署？" 7 50
        if [ $? -eq 0 ]; then
            SYSCTL_OPTIMIZE=$exit_status
            break
        fi
    done
}

back_previous_menu() {
    case $PREVIOUS_MENU in
        1) main_menu ;;
        2) deploy_menu ;;
        3) input_config_menu $TIMEZONE $DOMAIN $WARP_KEY ;;
        4) sysctl_menu ;;
    esac
}

exit_operation() {
    exit_status=$1
    case $exit_status in
        # Cancel
        1) exit 0 ;;
        # Previous
        3) back_previous_menu; return ;;
        # ESC
        255)
            dialog --yesno "是否要退出？" 7 50
            if [ $? -eq 0 ]; then
                exit 0
            else
                break
            fi
    esac
}

check_os_release() {
    echo "检查发行版 Checking os release..."
    if [ -f "/etc/os-release" ]; then
        . /etc/os-release
        OS=$NAME
    fi
}

install_missing_packages() {
    if ! command -v dialog &> /dev/null || ! command -v uuidgen &> /dev/null
    then
        echo "安装 dialog"
        if [[ "${OS,,}" == *"debian"* ]] || [[ "${OS,,}" == *"ubuntu"* ]]; then
            sudo apt-get update && sudo apt-get install -y dialog util-linux
        elif [[ "${OS,,}" == *"centos"* ]] || [[ "${OS,,}" == *"fedora"* ]]; then
            sudo dnf install -y dialog util-linux
        elif [[ "${OS,,}" == *"arch"* ]]; then
            sudo pacman -Sy --noconfirm dialog util-linux
        else
            echo "不支持的操作系统"
            exit 1
        fi
    fi
}

check_docker_env() {
    echo "检查 docker 环境 Checking docker ..."
    if ! command -v docker &> /dev/null
    then
        install_docker
    fi
}

install_docker() {
    echo "安装 docker 环境 Checking docker..."
    # enable ipv6 support
    sudo mkdir -p /etc/docker
    cat <<- EOF > /etc/docker/daemon.json
{
    "experimental": true,
    "ip6tables": true
}
EOF

    if [[ "${OS,,}" == *"ubuntu"* ]]; then
        # Uninstall conflicting packages:
        for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done;
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl uuid-runtime
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc

        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif [[ "${OS,,}" == *"debian"* ]]; then
        for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl uuid-runtime
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc

        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif [[ "${OS,,}" == *"centos"* ]]; then
        sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
        sudo yum install -y yum-utils util-linux
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif [[ "${OS,,}" == *"fedora"* ]]; then
        sudo dnf remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine
        sudo dnf install -y dnf-plugins-core util-linux
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    elif [[ "${OS,,}" == *"arch"* ]]; then
        sudo pacman -Syy && sudo pacman -S --noconfirm docker docker-compose util-linux
    else
        echo "Unsupported operating system"
        exit 1
    fi

    sudo usermod -a -G docker $USER
    enable_docker_service
}

enable_docker_service() {
    sudo systemctl enable docker 2>&1
    sudo systemctl start docker 2>&1
}

deploy() {
    {
        prepare_workdir
        prepare_configs
        docker compose pull 2>&1
        docker compose up -d 2>&1
        output_v2ray_config
    } | dialog --title "正在部署... Deploying..." --programbox 30 100
}

prepare_configs() {
        check_docker_env
        enable_docker_ipv6
        sysctl_config
        env_config
        docker_compose_config
        v2ray_config
        haproxy_config
        nginx_config
}

enable_docker_ipv6() {
    if [ ! -f "/etc/docker/daemon.json" ] || [ ! -s "/etc/docker/daemon.json" ]; then
        sudo mkdir -p /etc/docker
        sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "experimental": true,
    "ip6tables": true
}
EOF
    else
        content=$(cat /etc/docker/daemon.json)
        if [[ ! $content =~ \{.*\} ]]; then
            sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "experimental": true,
    "ip6tables": true
}
EOF
        else
            if ! grep -q "experimental" /etc/docker/daemon.json; then
                sudo sed -i 's/^{/{\n    "experimental": true,/' /etc/docker/daemon.json
            fi
            if ! grep -q "ip6tables" /etc/docker/daemon.json; then
                sudo sed -i 's/^{/{\n    "ip6tables": true,/' /etc/docker/daemon.json
            fi
            sudo sed -i 's/,\s*}/\n}/' /etc/docker/daemon.json
        fi
    fi
}

sysctl_config() {
    if [[ "$SYSCTL_OPTIMIZE" == 0 ]]; then
        echo "优化网络设置 Updating sysctl config..."
        if ! grep -q "* soft nofile 51200" /etc/security/limits.conf; then
            sudo tee -a /etc/security/limits.conf <<- EOF
* soft nofile 51200
* hard nofile 51200

root soft nofile 51200
root hard nofile 51200
EOF
        fi

        sudo mkdir -p /etc/sysctl.d/
        sudo tee /etc/sysctl.d/50-network.conf <<- EOF
fs.file-max = 51200

net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096

net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1

net.core.default_qdisc = fq
# net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_congestion_control = hybla
EOF

        ulimit -n 51200
        sudo sysctl --system
    fi
}

env_config() {
    cat <<- EOF > .env
TZ=${TIMEZONE}
DOMAIN=${DOMAIN}
WARP_KEY=${WARP_KEY}
EOF
}

docker_compose_config() {
    if [[ "$DEPLOY_CHOICES" == *"1"* ]]; then
        echo "下载 geodata. Downloading geodata..."
        mkdir -p ./config/geodata
        curl -sLo ./config/geodata/geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
        curl -sLo ./config/geodata/geosite.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
    fi

    echo "写入 docker 配置. Writing docker-compose config..."
    cat <<- EOF > docker-compose.yaml
services:

  haproxy_tcp:
    image: pandasrun/haproxy:latest
    container_name: haproxy_tcp
    volumes:
      - ./config/haproxy/haproxy.tcp.cfg:/usr/local/etc/haproxy/haproxy.cfg
      - ./config/certs/live/${DOMAIN}:/etc/ssl/certs
    networks:
      - ipv6
    ports:
      - 443:443/tcp
    restart: unless-stopped

  nginx:
    image: linuxserver/swag:latest
    container_name: nginx
    cap_add:
      - NET_ADMIN
    environment:
      - PUID=99
      - PGID=99
      - TZ=${TIMEZONE}
      - URL=${DOMAIN}
      - VALIDATION=http
      - EMAIL=${EMAIL}
    volumes:
      - ./config/nginx:/config/nginx
      - ./config/certs:/config/etc/letsencrypt
      - ./config/www:/config/www
    networks:
      - ipv6
    ports:
      - 80:80
    restart: unless-stopped

EOF

    if [[ "$DEPLOY_CHOICES" == *"1"* ]]; then
        cat <<- EOF >> docker-compose.yaml
  v2ray:
    image: pandasrun/v2ray:latest
    container_name: v2ray
    environment:
      - WAIT_PATHS=/etc/ssl/certs/v2ray/priv-fullchain-bundle.pem
    volumes:
      - ./config/v2ray/config.json:/etc/v2ray/config.json
      - ./config/geodata:/usr/share/v2ray
      - ./config/certs/live/${DOMAIN}:/etc/ssl/certs/v2ray
    networks:
      - ipv6
    restart: unless-stopped

EOF
    fi

    if [[ "$DEPLOY_CHOICES" == *"2"* ]]; then
        cat <<- EOF >> docker-compose.yaml
  warp:
    image: pandasrun/warp:latest
    container_name: warp
    environment:
      - WARP_KEY=${WARP_KEY}
    volumes:
      - ./config/warp:/var/lib/cloudflare-warp
    networks:
      - ipv6
    restart: unless-stopped

EOF
    fi

    if [[ "$DEPLOY_CHOICES" == *"3"* ]]; then
        cat <<- EOF >> docker-compose.yaml
  openvpn:
    image: pandasrun/openvpn:latest
    container_name: openvpn
    environment:
      - DOMAIN=${DOMAIN}
    volumes:
      - ./config/openvpn/server:/etc/openvpn/server
      - ./config/openvpn/client:/root/client-configs
    networks:
      - ipv6
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv6.conf.all.forwarding=1
    cap_add:
      - NET_ADMIN
    security_opt:
      - no-new-privileges
    restart: unless-stopped

EOF
    fi

    if [[ "$DEPLOY_CHOICES" == *"4"* ]]; then
        smokeping_config
        cat <<- EOF >> docker-compose.yaml
  smokeping:
    image: lscr.io/linuxserver/smokeping:latest
    container_name: smokeping
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Shanghai
      #- MASTER_URL= #optional
      #- SHARED_SECRET=password #optional
      #- CACHE_DIR=/tmp #optional
    volumes:
      - ./config:/config
      - ./data:/data
    restart: unless-stopped

EOF

    cat <<- EOF >> docker-compose.yaml
networks:
  ipv6:
    enable_ipv6: true
    ipam:
      config:
        - subnet: 2001:0DB9::/112
EOF

}

v2ray_config() {
    echo "写入 V2Ray 配置... Writing V2Ray config..."
    mkdir -p ./config/v2ray/
    PUBLIC_IP=$(timeout 3 curl -s https://ipinfo.io/ip)
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP=$(timeout 3 curl -s https://6.ipinfo.io/ip)
        if [ -z "$PUBLIC_IP" ]; then
            PUBLIC_IP="127.0.0.1"
        fi
    fi
    UUID=$(uuidgen)
    SERVICE_NAME=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    cat <<- EOF > ./config/v2ray/config.json
{
    "log": {
        "loglevel": "warning"
    },
    "dns": {
        "hosts": {
            "geosite:category-ads-all": "127.0.0.1"
        },
        "servers": [
            "1.1.1.1",
            "8.8.8.8",
            "https+local://cloudflare-dns.com/dns-query",
            "https+local://dns.google/dns-query"
        ],
        "clientIp": "${PUBLIC_IP}"
    },
    "inbounds": [
        {
            "tag": "tcp",
            "protocol": "vmess",
            "listen": "0.0.0.0",
            "port": 8001,
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}"
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "certificates": [
                        {
                            "certificateFile": "/etc/ssl/certs/v2ray/priv-fullchain-bundle.pem",
                            "keyFile": "/etc/ssl/certs/v2ray/priv-fullchain-bundle.pem"
                        }
                    ]
                }
            }
        },
        {
            "tag": "h2",
            "protocol": "vmess",
            "listen": "0.0.0.0",
            "port": 8002,
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}"
                    }
                ]
            },
            "streamSettings": {
                "network": "h2"
            }
        },
        {
            "tag": "grpc",
            "protocol": "vmess",
            "listen": "0.0.0.0",
            "port": 8003,
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}"
                    }
                ]
            },
            "streamSettings": {
                "network": "grpc",
                "grpcSettings": {
                    "serviceName": "${SERVICE_NAME}"
                }
            }
        },
        {
            "tag": "quic",
            "protocol": "vmess",
            "listen": "0.0.0.0",
            "port": 8004,
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}"
                    }
                ]
            },
            "streamSettings": {
                "network": "quic",
                "quicSettings": {
                    "security": "chacha20-poly1305",
                    "key": "",
                    "header": {
                        "type": "none"
                    }
                }
            }
        },
        {
            "tag": "dns-in",
            "protocol": "dokodemo-door",
            "port": 53,
            "settings": {
                "address": "1.1.1.1",
                "port": 53,
                "network": "tcp,udp",
                "userLevel": 1
            }
        }
    ],
    "outbounds": [
        // first one is the default option
        // could be omitted in "routing" block below
        {
            "tag": "freedom",
            "protocol": "freedom"
        },
        {
            "tag": "cf-warp",
            "protocol": "socks",
            "settings": {
                "servers": [
                    {
                        "address": "warp",
                        "port": 40001
                    }
                ]
            }
        },
        {
            "tag": "blocked",
            "protocol": "blackhole"
        },
        {
            "tag": "dns-out",
            "protocol": "dns",
            "proxySettings": {
                "tag": "remote-proxy-out"
            }
        }
    ],
    "routing": {
        "domainStrategy": "AsIs",
        "domainMatcher": "mph",
        "rules": [
            {
                "type": "field",
                "inboundTag": [
                    "dns-in"
                ],
                "outboundTag": "dns-out"
            },
            {
                "outboundTag": "cf-warp",
                "type": "field",
                "domain": [
                    "geosite:openai"
                ]
            },
            {
                "outboundTag": "blocked",
                "type": "field",
                "domain": [
                    "geosite:category-ads-all"
                ]
            },
            {
                "outboundTag": "blocked",
                "type": "field",
                "protocol": [
                    "bittorrent"
                ]
            }
        ]
    },
    "policy": {
        "system": {
            "statsInboundUplink": false,
            "statsInboundDownlink": false,
            "statsOutboundUplink": false,
            "statsOutboundDownlink": false
        },
        "levels": {
            "0": {
                "handshake": 4,
                "connIdle": 300,
                "uplinkOnly": 2,
                "downlinkOnly": 5,
                "statsUserUplink": false,
                "statsUserDownlink": false,
                "bufferSize": 10240
            }
        }
    }
}
EOF
}

haproxy_config() {
    echo "写入 HAProxy 配置... Writing HAProxy configs..."
    # HAProxy TCP Configuration
    mkdir -p ./config/haproxy/
    cat <<- EOF > ./config/haproxy/haproxy.tcp.cfg
global
    log stdout format raw local0 info
    stats timeout 30s
    daemon

    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11
    ssl-server-verify none

defaults
    mode tcp
    log global
    option tcplog
    option tcpka
    option redispatch
    option dontlognull
    timeout connect 5s
    timeout client 300s
    timeout server 300s
    timeout queue 1m

frontend tls-in
    bind :::443 v4v6

    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }
    tcp-request content accept if HTTP

    acl is_h2 req.ssl_alpn -i h2
    acl is_h1 req.ssl_alpn -i http/1.1
    acl has_sni req.ssl_sni -m found

EOF

    if [[ "$DEPLOY_CHOICES" == *"1"* ]]; then
        cat <<- EOF >> ./config/haproxy/haproxy.tcp.cfg
    use_backend v2ray_tcp if !is_h1 !is_h2 has_sni
EOF
    fi

    if [[ "$DEPLOY_CHOICES" == *"3"* ]]; then
        cat <<- EOF >> ./config/haproxy/haproxy.tcp.cfg
    use_backend openvpn if !is_h1 !is_h2 !has_sni
EOF
    fi

    cat <<-EOF >> ./config/haproxy/haproxy.tcp.cfg
    default_backend nginx

backend nginx
    server nginx nginx:443

EOF

    if [[ "$DEPLOY_CHOICES" == *"1"* ]]; then
        cat <<- EOF >> ./config/haproxy/haproxy.tcp.cfg
backend v2ray_tcp
    server v2ray v2ray:8001

EOF
    fi

    if [[ "$DEPLOY_CHOICES" == *"3"* ]]; then
        cat <<- EOF >> ./config/haproxy/haproxy.tcp.cfg
backend openvpn
    server openvpn openvpn:443
EOF
    fi

}

nginx_config() {
    echo "写入 nginx 配置... Writing Nginx config..."
    mkdir -p ./config/nginx/site-confs/
    mkdir -p ./config/www/
    curl -sLo ./config/www/index.html https://raw.githubusercontent.com/PandaRyshan/ladder/main/config/www/index.html
    cat <<- EOF > ./config/nginx/site-confs/default.conf
## Version 2024/07/16 - https://github.com/linuxserver/docker-swag/blob/master/root/defaults/nginx/site-confs/default.conf.sample
## Changelog: https://github.com/linuxserver/docker-swag/commits/master/root/defaults/nginx/site-confs/default.conf.sample

server {
    listen 80 default_server;
    listen [::]:80 default_server;

    location / {
        return 301 https://\$host$request_uri;
    }
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;

    server_name _;

    include /config/nginx/ssl.conf;

    root /config/www;
    index index.html index.htm index.php;

    include /config/nginx/proxy-confs/*.subfolder.conf;

    location / {
        try_files \$uri \$uri/ /index.html /index.htm /index.php\$is_args\$args;
    }

    location /${SERVICE_NAME} {
        if ( \$content_type !~ "application/grpc") {
            return 404;
        }

        if ( \$request_method != "POST" ) {
            return 404;
        }

        client_body_timeout 300s;
        client_max_body_size 0;
        client_body_buffer_size 32k;
        grpc_connect_timeout 10s;
        proxy_buffering off;
        grpc_read_timeout 300s;
        grpc_send_timeout 300s;
        grpc_socket_keepalive on;
        grpc_pass grpc://grpc_backend;

        grpc_set_header Connection "";
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
EOF

    if [[ "$DEPLOY_CHOICES" == *"4"* ]]; then
    cat <<- EOF > ./config/nginx/site-confs/default.conf
    location /smokeping {
        proxy_pass http://smokeping:80;
    }
EOF
    fi

    cat <<- EOF > ./config/nginx/site-confs/default.conf
    location ~ /\.ht {
        deny all;
    }
}

upstream grpc_backend {
    server v2ray:8003;
    keepalive 500;
    keepalive_timeout 7d;
    keepalive_requests 100000;
}

include /config/nginx/proxy-confs/*.subdomain.conf;
proxy_cache_path cache/ keys_zone=auth_cache:10m;
EOF
}

smokeping_config() {
    echo "写入 SmokePing 配置... Writing SmokePing config..."
    mkdir -p ./config/smokeping
    cat <<- EOF > ./config/smokeping/Targets
*** Targets ***

probe = FPing

menu = Top
title = Network Latency Grapher
remark = Welcome to the SmokePing website of WORKS Company. \
         Here you will learn all about the latency of our network.

+ InternetSites

menu = Internet Sites
title = Internet Sites

++ BeijingUnicom
menu = Beijing Unicom
title = Beijing Unicom
host = 202.106.50.1

++ BeijingTelecom
menu = Beijing Telecom
title = Beijing Telecom
host = 219.141.136.12

++ BeijingMobile
menu = Beijing Mobile
title = Beijing Mobile
host = 221.179.155.161

++ X.com
menu = X.com
title = X.com
host = x.com

++ Youtube
menu = YouTube
title = YouTube
host = youtube.com

++ JupiterBroadcasting
menu = JupiterBroadcasting
title = JupiterBroadcasting
host = jupiterbroadcasting.com

++ GoogleSearch
menu = Google
title = google.com
host = google.com

++ GoogleSearchIpv6
menu = Google
probe = FPing6
title = ipv6.google.com
host = ipv6.google.com

++ linuxserverio
menu = linuxserver.io
title = linuxserver.io
host = linuxserver.io

+ DNS
menu = DNS
title = DNS

++ GoogleDNS1
menu = Google DNS 1
title = Google DNS 8.8.8.8
host = 8.8.8.8

++ GoogleDNS2
menu = Google DNS 2
title = Google DNS 8.8.4.4
host = 8.8.4.4

++ OpenDNS1
menu = OpenDNS1
title = OpenDNS1
host = 208.67.222.222

++ OpenDNS2
menu = OpenDNS2
title = OpenDNS2
host = 208.67.220.220

++ CloudflareDNS1
menu = Cloudflare DNS 1
title = Cloudflare DNS 1.1.1.1
host = 1.1.1.1

++ CloudflareDNS2
menu = Cloudflare DNS 2
title = Cloudflare DNS 1.0.0.1
host = 1.0.0.1

++ L3-1
menu = Level3 DNS 1
title = Level3 DNS 4.2.2.1
host = 4.2.2.1

++ L3-2
menu = Level3 DNS 2
title = Level3 DNS 4.2.2.2
host = 4.2.2.2

++ Quad9
menu = Quad9
title = Quad9 DNS 9.9.9.9
host = 9.9.9.9

+ DNSProbes
menu = DNS Probes
title = DNS Probes
probe = DNS

++ GoogleDNS1
menu = Google DNS 1
title = Google DNS 8.8.8.8
host = 8.8.8.8

++ GoogleDNS2
menu = Google DNS 2
title = Google DNS 8.8.4.4
host = 8.8.4.4

++ OpenDNS1
menu = OpenDNS1
title = OpenDNS1
host = 208.67.222.222

++ OpenDNS2
menu = OpenDNS2
title = OpenDNS2
host = 208.67.220.220

++ CloudflareDNS1
menu = Cloudflare DNS 1
title = Cloudflare DNS 1.1.1.1
host = 1.1.1.1

++ CloudflareDNS2
menu = Cloudflare DNS 2
title = Cloudflare DNS 1.0.0.1
host = 1.0.0.1

++ L3-1
menu = Level3 DNS 1
title = Level3 DNS 4.2.2.1
host = 4.2.2.1

++ L3-2
menu = Level3 DNS 2
title = Level3 DNS 4.2.2.2
host = 4.2.2.2

++ Quad9
menu = Quad9
title = Quad9 DNS 9.9.9.9
host = 9.9.9.9
EOF
}

pull_images() {
    {
        sudo docker compose pull 2>&1
    } | dialog --title "正在拉取镜像..." --programbox 20 70
}

up_containers() {
    {
        sudo docker compose up -d 2>&1
    } | dialog --title "正在部署容器..." --programbox 20 70
}

start_containers() {
    {
        sudo docker compose start 2>&1
    } | dialog --title "正在启动容器..." --programbox 20 70
}

upgrade_containers() {
    {
        sudo docker compose pull 2>&1
    } | dialog --title "正在更新容器..." --programbox 20 70
}

stop_containers() {
    {
        sudo docker compose stop 2>&1
    } | dialog --title "正在停止容器..." --programbox 20 70
}

restart_containers() {
    {
        sudo docker compose restart 2>&1
    } | dialog --title "正在重启容器..." --programbox 20 70
}

down_containers() {
    {
        sudo docker compose down 2>&1
    } | dialog --title "正在卸载容器..." --programbox 20 70
}

prepare_workdir() {
    cd "$(dirname "$0")"
    if [[ "$(basename "$PWD")" != "ladder" ]]; then
        echo "创建 ladder 工作目录..."
        mkdir -p ./ladder && cd ./ladder
        mv -f ../setup.sh .
    fi
}

output_v2ray_config() {
    max_len=$(echo -e "${DOMAIN}\n${UUID}\n${SERVICE_NAME}" | wc -L)
    {
        echo ""
        echo "安装脚本已移动至容器配置目录：${pwd}"
        echo "V2Ray 配置："
        printf "+--------------+-%-${max_len}s-+\n" | sed "s/ /-/g"
        printf "| %-12s | %-${max_len}s |\n" "Domain:" "${DOMAIN}"
        printf "| %-12s | %-${max_len}s |\n" "Protocol:" "grpc"
        printf "| %-12s | %-${max_len}s |\n" "UUID:" "${UUID}"
        printf "| %-12s | %-${max_len}s |\n" "ServiceName:" "${SERVICE_NAME}"
        printf "| %-12s | %-${max_len}s |\n" "TLS:" "Yes"
        printf "+--------------+-%-${max_len}s-+\n" | sed "s/ /-/g"
        echo ""
        echo "OpenVPN 配置可通过地址 https://${DOMAIN}/client-xxxx.ovpn 的方式下载"
    } | tee $(pwd)/info.txt
}

# Main 主程序
check_os_release
install_missing_packages
main_menu
