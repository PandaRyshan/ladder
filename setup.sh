#!/bin/bash

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
			1)
				status_menu
				;;
			2)
				deploy_menu
				input_config
				sysctl_menu
				deploy
				break
				;;
			3)
				restart_containers
				;;
			4)
				upgrade_containers
				;;
			5)
				stop_containers
				;;
			6)
				down_containers
				;;
			*)
				;;
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

input_config() {
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
		TIMEZONE=$(sed -n '1p' <<< $result)
		DOMAIN=$(sed -n '2p' <<< $result)
		WARP_KEY=$(sed -n '3p' <<< $result)

		case $exit_status in
			1)
				# Cancel
				exit 0
				;;
			3)
				# Previous
				main_menu
				;;
			255)
				# ESC
				dialog --yesno "是否要退出？" 7 50
				if [ $? -eq 0 ]; then
					exit 0
				fi
		esac

		if [ -z "$TIMEZONE" ] || [ -z "$DOMAIN" ]; then
			dialog --msgbox "所有信息均为必填，请继续输入。" 7 50
		else
			break
		fi
	done
}

sysctl_menu() {
	while true; do
		dialog --clear \
			--title "优化 sysctl.conf" \
			--extra-button --extra-label "Previous" \
			--yesno "是否优化 sysctl.conf？" 7 50

		exit_status=$?
		case $exit_status in
			3)
				# Previous
				input_config $TIMEZONE $DOMAIN $WARP_KEY
				;;
			255)
				# ESC
				dialog --yesno "是否要退出？" 7 50
				if [ $? -eq 0 ]; then
					exit 0
				fi
		esac

		dialog --yesno "确认开始部署？" 7 50
		if [ $? -eq 0 ]; then
            SYSCTL_OPTIMIZE=$exit_status
			break
		fi
	done
}

check_os_release() {
	echo "检查发行版 Checking os release..."
	if [ -f "/etc/os-release" ]; then
		. /etc/os-release
		OS=$NAME
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
		sudo apt-get install -y ca-certificates curl
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
		sudo apt-get install -y ca-certificates curl
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
		sudo yum install -y yum-utils
		sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
		sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin wget git uuid-runtime
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
		sudo dnf install -y dnf-plugins-core
		sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
	elif [[ "${OS,,}" == *"arch"* ]]; then
		sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin wget git uuid-runtime
		sudo pacman -Syy && sudo pacman -S --noconfirm docker docker-compose wget git
	else
		echo "Unsupported operating system"
		exit 1
	fi

	sudo usermod -a -G docker $USER
	enable_docker_service
}

enable_docker_service() {
	sudo systemctl start docker
	sudo systemctl enable docker
}

deploy() {
	{
		prepare_configs
		docker compose pull 2>&1
		docker compose up -d 2>&1
	} | dialog --title "正在部署... Deploying..." --programbox 20 70
}

prepare_configs() {
		check_docker_env
		enable_docker_ipv6
		sysctl_config
		env_config
		docker_compose_config
		haproxy_config
		nginx_config
		v2ray_config
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
TZ=$timezone
DOMAIN=$domain
WARP_KEY=$warp_key
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
    PUID=$(id -u)
    PGID=$(id -g)
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

  haproxy_http:
    image: pandasrun/haproxy:latest
    container_name: haproxy_http
    volumes:
      - ./config/haproxy/haproxy.http.cfg:/usr/local/etc/haproxy/haproxy.cfg
      - ./config/certs/live/${DOMAIN}:/etc/ssl/certs
    networks:
      - ipv6
    restart: unless-stopped

  nginx:
    image: linuxserver/swag:latest
    container_name: nginx
    cap_add:
      - NET_ADMIN
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TIMEZONE}
      - URL=${DOMAIN}
      - VALIDATION=http
      - EMAIL=${EMAIL}
    volumes:
      - ./config/nginx:/config
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
    volumes:
      - ./config/v2ray/config.json:/etc/v2ray/config.json
      - ./config/geodata:/usr/share/v2ray
      - ./config/certs:/etc/letsencrypt
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
    restart: unless-stopped

EOF
	fi

	cat <<- EOF >> docker-compose.yaml
networks:
  ipv6:
    enable_ipv6: true
    ipam:
      config:
        - subnet: 2001:0DB9::/112
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

    acl has_sni req.ssl_sni -m found

EOF

	if [[ "$DEPLOY_CHOICES" == *"3" ]]; then
		cat <<- EOF >> ./config/haproxy/haproxy.tcp.cfg
    use_backend openvpn if !has_sni
EOF
	fi

	cat <<-EOF >> ./config/haproxy/haproxy.tcp.cfg
    default_backend haproxy_http

backend haproxy_http
    server haproxy haproxy_http:443

EOF

	if [[ "$DEPLOY_CHOICES" == *"3"* ]]; then
		cat <<- EOF >> ./config/haproxy/haproxy.tcp.cfg
backend openvpn
    server openvpn openvpn:443
EOF
	fi

	# HAProxy HTTP Configuration
	cat <<- EOF > ./config/haproxy/haproxy.http.cfg
global
    log stdout format raw local0 info
    stats timeout 30s
    daemon

    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11
    tune.ssl.default-dh-param 2048
    crt-base /etc/ssl/certs
	
defaults
    mode http
    log global
    option http-keep-alive
    option httplog
    option dontlognull
    timeout connect 5s
    timeout client 300s
    timeout server 300s

frontend http-in
    bind :::443 v4v6 ssl crt priv-fullchain-bundle.pem proto h2 alpn h2,http/1.1
    bind quic4@:443 v4v6 ssl crt priv-fullchain-bundle.pem alpn h3

    tcp-request inspect-delay 5s
    http-request redirect scheme https unless { ssl_fc }
    http-after-response add-header alt-svc 'h3=":443"; ma=900'

EOF

	if [[ "$DEPLOY_CHOICES" == *"1"* ]]; then
		cat <<- EOF >> ./config/haproxy/haproxy.http.cfg
    acl gRPC hdr(content-type) -i application/grpc

    use_backend v2ray_grpc if gRPC
EOF
	fi

	cat <<- EOF >> ./config/haproxy/haproxy.http.cfg
    default_backend web

backend web
    server web nginx:443 alpn h2 check

EOF

	if [[ "$DEPLOY_CHOICES" == *"1"* ]]; then
		cat <<- EOF >> ./config/haproxy/haproxy.http.cfg
backend v2ray_grpc
    server v2ray v2ray:10088 proto h2 check
EOF
	fi

}

nginx_config() {
	echo "写入 nginx 配置... Writing Nginx config..."
    mkdir -p ./config/nginx/site-confs/
	cat <<- EOF > ./config/nginx/site-confs/default.conf
## Version 2024/07/16 - https://github.com/linuxserver/docker-swag/blob/master/root/defaults/nginx/site-confs/default.conf.sample
## Changelog: https://github.com/linuxserver/docker-swag/commits/master/root/defaults/nginx/site-confs/default.conf.sample

server {
    listen 80 default_server;
    listen [::]:80 default_server;

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
	# SSL enabled in HAProxy, no need to enable in nginx
    listen 443 default_server;
    listen [::]:443 default_server;

    server_name _;

    include /config/nginx/ssl.conf;

    root /config/www;
    index index.html index.htm index.php;

    include /config/nginx/proxy-confs/*.subfolder.conf;

    location / {
        try_files $uri $uri/ /index.html /index.htm /index.php$is_args$args;
    }

    location ~ /\.ht {
        deny all;
    }
}

include /config/nginx/proxy-confs/*.subdomain.conf;
proxy_cache_path cache/ keys_zone=auth_cache:10m;
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
            "port": 10010,
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
                    "certificates": [{
                        "certificateFile": "/etc/letsencrypt/live/${DOMAIN}/priv-fullchain-bundle.pem",
                        "keyFile": "/etc/letsencrypt/live/${DOMAIN}/priv-fullchain-bundle.pem"
                    }]
                }
            }
        },
        {
            "tag": "h2",
            "protocol": "vmess",
            "listen": "0.0.0.0",
            "port": 10086,
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
            "port": 10088,
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
            "port": 10000,
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
            "protocol": "dns"
        }
    ],
    "routing": {
        "domainStrategy": "AsIs",
        "domainMatcher": "mph",
        "rules": [
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

pull_images() {
	{
		docker compose pull 2>&1
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

exit_operation() {
	exit_status=$1
	case $exit_status in
		1)
			# Cancel
			exit 0
			;;
		3)
			# Previous
			main_menu
			;;
		255)
			# ESC
			dialog --yesno "是否要退出？" 7 50
			if [ $? -eq 0 ]; then
				exit 0
			fi
	esac
}

# 主程序

# 如果没有 dialog 则安装
check_os_release

if ! command -v dialog &> /dev/null
then
	echo "安装 dialog"
	if [[ "${OS,,}" == *"debian"* ]] || [[ "${OS,,}" == *"ubuntu"* ]]; then
		sudo apt-get update && sudo apt-get install -y dialog
	elif [[ "${OS,,}" == *"centos"* ]] || [[ "${OS,,}" == *"fedora"* ]]; then
		sudo dnf install -y dialog
	elif [[ "${OS,,}" == *"arch"* ]]; then
		sudo pacman -Sy --noconfirm dialog
	else
		echo "不支持的操作系统"
		exit 1
	fi
fi

cd "$(dirname "$0")"
main_menu
