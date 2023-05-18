#!/bin/bash

# Menu
function top_menu {
	echo ""
	echo "1. 部署 Deploy"
	echo "2. 升级 Upgrade"
	echo "3. 卸载 Uninstall"
	echo "0. 退出 Exit"
	echo ""
	read -p "请输入数字 Please enter a number: " option

	if [ "$option" == "0" ]; then
		exit 0
	elif [ "$option" == "1" ]; then
		install_menu
	elif [ "$option" == "2" ]; then
		upgrade
	elif [ "$option" == "3" ]; then
		remove
	else
		invalid_input
		install_menu
	fi
}

function install_menu {
	echo ""
	echo "部署选项 Deployment Option:"
	echo ""
	echo "1. 部署 V2Ray"
	echo "2. 部署 OpenConnect"
	echo "3. 全部 Deploy All"
	echo "0. 返回 Return"
	echo ""
	read -p "请输入数字 Please enter a number: " option

	if [ "$option" == "0" ]; then
		top_menu
	elif [ "$option" == "1" ]; then
		install_v2ray
	elif [ "$option" == "2" ]; then
		install_ocserv
	elif [ "$option" == "3" ]; then
		install_all
	else
		invalid_input
		install_menu
	fi

	return $option
}

# Receive user input and bind to environment variables
function input_info {
	echo ""
	read -p "邮箱 Email: " email
	read -p "域名 Domain: " domain
	read -p "V2Ray子域 Subdomain: " v2ray_sub
	if [ "$option" == "2" ] || [ "$option" == "3" ]; then
		read -p "Ocserv子域 Subdomain: " ocserv_sub
		read -p "用户名 Username: " username
		read -p "密码 Password: " password
	fi
	echo ""
	read -p "请确认 (y/n):" confirm
	# Convert to lowercase
	confirm=$(echo $confirm | tr '[:upper:]' '[:lower:]')
	if [ "$confirm" == "y" ]; then
		export DOMAIN="$domain"
		export EMAIL="$email"
		export V2RAY_SUB="$v2ray_sub"
		if [ "$option" == "2" ] || [ "$option" == "3" ]; then
			export OCSERV_SUB="$ocserv_sub"
			export USERNAME="$username"
			export PASSWORD="$password"
		fi
	elif [ "$confirm" == "n" ]; then
		echo ""
		echo "重新输入 Re-input"
		input_info
	else
		invalid_input
		exit 1
	fi
}

function invalid_input {
	echo ""
	echo "\033[31m无效输入 Invalid input\033[0m"
}

function check_os_release {
	if [ -f /etc/os-release ]; then
		. /etc/os-release
		OS=$NAME
	fi
}

function prepare_os_env {
	if [[ "${OS,,}" == *"ubuntu"* ]]; then
		sudo apt-get remove -y docker docker-engine docker.io containerd runc
		sudo apt-get update
		sudo apt-get install -y ca-certificates curl gnupg
		sudo install -m 0755 -d /etc/apt/keyrings
		yes | curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
		sudo chmod a+r /etc/apt/keyrings/docker.gpg
		echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
		sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
		sudo apt-get update
		sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin wget git
		apt update && apt install -y wget git docker-ce docker-compose-plugin
	elif [[ "${OS,,}" == *"debian"* ]]; then
		sudo apt-get remove docker docker-engine docker.io containerd runc
		sudo apt-get update
		sudo apt-get install ca-certificates curl gnupg
		sudo install -m 0755 -d /etc/apt/keyrings
		curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
		sudo chmod a+r /etc/apt/keyrings/docker.gpg
		echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
		sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
		sudo apt-get update
		sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin wget git
		apt update && apt install -y wget git docker-ce docker-compose-plugin
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
		sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin wget git
		sudo systemctl start docker
		sudo systemctl enable docker
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
		sudo dnf -y install dnf-plugins-core
		sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
		sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
		sudo systemctl start docker
		sudo systemctl enable docker
	elif [[ "${OS,,}" == *"arch"* ]]; then
		sudo pacman -Syy && sudo pacman -S --noconfirm docker docker-compose wget git
	else
		echo "Unsupported operating system"
		exit 1
	fi
}

function prepare_config {
	if [ ! -f "./docker-compose" ]; then
		git clone https://github.com/PandaRyshan/ladder.git
		cd ladder
	fi
	cat > .env <<- EOENV
		TZ=Asia/Shanghai
		EMAIL=${EMAIL}
		DOMAIN=${DOMAIN}
		V2RAY_SUB=${V2RAY_SUB}
		OCSERV_SUB=${OCSERV_SUB}
		USERNAME=${USERNAME}
		PASSWORD=${PASSWORD}
	EOENV
	cp -f ./config/v2ray/config.json.sample ./config/v2ray/config.json
	cp -f ./config/nginx/site-confs/default.conf.sample ./config/nginx/site-confs/default.conf
	cp -f ./config/haproxy/haproxy.cfg.sample ./config/haproxy/haproxy.cfg
	cp -f ./config/ocserv/ocserv.conf.sample ./config/ocserv/ocserv.conf

	# set up timezone
	ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	sudo timedatectl set-timezone Asia/Shanghai

	sed -i "s/<your-host-ip>/$(curl -s https://ifconfig.me)/g" ./config/v2ray/config.json
	sed -i "s/<your-v2ray-domain>/${V2RAY_SUB}.${DOMAIN}/g" ./config/v2ray/config.json
	sed -i "s/<your-vpn-domain>/${OCSERV_SUB}.${DOMAIN}/g" ./config/haproxy/haproxy.cfg
	sed -i "s/<your-v2ray-domain>/${V2RAY_SUB}.${DOMAIN}/g" ./config/haproxy/haproxy.cfg
	sed -i "s/<your-vpn-domain>/${OCSERV_SUB}.${DOMAIN}/g" ./config/ocserv/ocserv.conf

	# download latest geoip.dat and geosite.dat to ./geodata directory
	mkdir -p ./config/geodata
	wget -P ./config/geodata https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
	wget -P ./config/geodata https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
}

function start_containers {
	cd_script_dir
	docker compose up -d
}

function install_all {
	cd_script_dir
	check_os_release
	input_info
	prepare_os_env
	prepare_config
	start_containers
}

function upgrade {
	cd_script_dir
	git stash && git fetch && git pull
	docker pull v2fly/v2fly-core
	docker compose up -d v2ray
}

function remove {
	cd_script_dir
	docker compose down
}

function help {
	echo "Usage: setup.sh [OPTION]..."
	echo "Setup V2Ray and OpenConnect on Linux"
	echo ""
	echo "  -i, --install	install V2Ray and OpenConnect"
	echo "  -u, --upgrade	upgrade V2Ray and OpenConnect"
	echo "  -r, --remove	remove V2Ray and OpenConnect"
	echo "  -h, --help		display this help and exit"
}

function cd_script_dir {
	cd "$(dirname "$0")"
}


cd_script_dir

while [[ $# -gt 0 ]]; do
	case $1 in
		-i|--install)
			install_menu
			;;
		-u|--upgrade)
			upgrade
			;;
		-r|--remove|--uninstall)
			remove
			;;
		-h|--help)
			help
			;;
		*)
			echo "Invalid option: -$1"
			exit 1
			;;
	esac
	exit 0
done

top_menu