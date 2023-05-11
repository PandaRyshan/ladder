#!/bin/bash

# Menu
function show_menu {
	echo ""
	echo "部署选项 Deployment Option:"
	echo ""
	echo "1. 部署 V2Ray"
	echo "2. 部署 OpenConnect"
	echo "3. 全部 Deploy All"
	echo ""
	read -p "请输入数字 Please enter a number: " option
	if [ "$option" != "1" ] && [ "$option" != "2" ] && [ "$option" != "3" ]; then
		invalid_input
		show_menu
	fi
	return $option
}

# Receive user input and bind to environment variables
function input_info {
	echo ""
	read -p "域名 Domain: " domain
	read -p "邮箱 Email: " email
	if [ "$option" == "2" ] || [ "$option" == "3" ]; then
		read -p "用户名 Username: " username
		read -p "密码 Password: " password
	fi
	echo ""
	read -p "请确认 (Y/N):" confirm
	# Convert to lowercase
	confirm=$(echo $confirm | tr '[:upper:]' '[:lower:]')
	if [ "$confirm" == "y" ]; then
		export DOMAIN="$domain"
		export EMAIL="$email"
		if [ "$option" == "1" ] || [ "$option" == "3" ]; then
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
	git clone https://github.com/PandaRyshan/v2ray.git
	cd v2ray
    cp ./config/v2ray/config.json.sample ./config/v2ray/config.json
	cp ./config/nginx/site-confs/default.conf.sample ./config/nginx/site-confs/default.conf
    cp ./config/haproxy/haproxy.cfg.sample ./config/haproxy/haproxy.cfg
	cat > .env <<- EOENV
		TZ=Asia/Shanghai
		DOMAIN=${DOMAIN}
		EMAIL=${EMAIL}
		USERNAME=${USERNAME}
		PASSWORD=${PASSWORD}
	EOENV

	# set up timezone
	ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	sudo timedatectl set-timezone Asia/Shanghai

	# replace <your-host-ip> with your IP address
	sed -i "s/<your-host-ip>/$(curl -s https://ifconfig.me)/g" ./config/v2ray/config.json

	# download geoip.dat and geosite.dat to ./geodata directory
	mkdir -p ./geodata
	wget -P ./geodata https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
	wget -P ./geodata https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat

	# replace <your-domain> with your domain
	sed -i "s/<your-domain>/${DOMAIN}/g" ./config/haproxy/haproxy.cfg
}

function start_containers {
	docker compose up -d
}

function install {
	show_menu
	check_os_release
	input_info
	prepare_os_env
	prepare_config
	start_containers
}

function update {
	git stash && git fetch && git pull
	docker pull v2fly/v2fly-core
	docker compose up -d v2ray
}

function remove {
	docker compose down
}

function help {
	echo "Usage: setup.sh [OPTION]..."
	echo "Setup V2Ray and OpenConnect on Linux"
	echo ""
	echo "  -i, --install	install V2Ray and OpenConnect"
	echo "  -u, --update	update V2Ray and OpenConnect"
	echo "  -r, --remove	remove V2Ray and OpenConnect"
	echo "  -h, --help		display this help and exit"
}


cd "$(dirname "$0")"

while [[ $# -gt 0 ]]; do
	case $1 in
		-i|--install)
			install
			;;
		-u|--update)
			update
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

install