#!/bin/bash

# Menu
function top_menu {
	echo ""
	echo "1. 部署 V2Ray + OpenConnect"
	echo "2. 升级"
	echo "3. 卸载"
	echo "0. 退出"
	echo ""
	read -p "请输入数字: " option

	if [ "$option" == "0" ]; then
		exit 0
	elif [ "$option" == "1" ]; then
		# install_menu
		install_all
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
	echo "以下所有信息均为必填"
	echo ""
	echo "域名填写注意："
	echo "如 www.example.com，主域名为 example.com，子域名为 www"
	echo ""
	read -p "主域名: " domain
	read -p "V2Ray 子域域名: " v2ray_sub
	read -p "OpenConnect 子域名: " ocserv_sub
	echo ""
	read -p "OpenConnect 用户名: " username
	read -p "OpenConnect 密码: " password
	echo ""
	read -p "邮箱（证书更新失败提醒）: " email
	echo ""
	read -p "请确认 (y/n):" confirm
	# Convert to lowercase
	confirm=$(echo $confirm | tr '[:upper:]' '[:lower:]')
	if [ "$confirm" == "y" ]; then
		export DOMAIN="$domain"
		export EMAIL="$email"
		export V2RAY_SUB="$v2ray_sub"
		export OCSERV_SUB="$ocserv_sub"
		export USERNAME="$username"
		export PASSWORD="$password"
		export V2RAY_DOMAIN=${V2RAY_SUB}.${DOMAIN}
		export OCSERV_DOMAIN=${OCSERV_SUB}.${DOMAIN}
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
	echo "checking os release..."
	if [ -f "/etc/os-release" ]; then
		. /etc/os-release
		OS=$NAME
	fi
}

function prepare_sysconfig {
	file_path="/etc/security/limits.conf"
	if [ ! -f "$file_path" ]; then
		echo "creating $file_path..."
		sudo touch $file_path
	fi
	temp_file=$(mktemp)	
	sudo awk '{if ($1 !~ /^#/ && $1 != "") print "#"$0; else print $0}' $file_path > $temp_file
	cat >> $temp_file <<- EOF
	* soft nofile 51200
	* hard nofile 51200
	root soft nofile 51200
	root hard nofile 51200
	EOF
	sudo mv $temp_file $file_path
	ulimit -n 51200

	file_path="/etc/sysctl.conf"
	if [ ! -f "$file_path" ]; then
		echo "creating $file_path..."
		sudo touch $file_path
	fi
	temp_file=$(mktemp)
	sudo awk '{if ($1 !~ /^#/ && $1 != "") print "#"$0; else print $0}' $file_path > $temp_file
	cat >> $temp_file <<- EOF
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
	sudo mv $temp_file $file_path
	sudo sysctl -p
}

function prepare_os_env {
	echo "preparing os environment..."
	if [[ "${OS,,}" == *"ubuntu"* ]]; then
		sudo apt remove -y docker docker-engine docker.io containerd runc
		sudo apt update
		sudo apt install -y ca-certificates curl gnupg
		sudo install -m 0755 -d /etc/apt/keyrings
		sudo rm -f /etc/apt/keyrings/docker.gpg
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
		sudo chmod a+r /etc/apt/keyrings/docker.gpg
		echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
		sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
		sudo apt update
		sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin wget git uuid-runtime
	elif [[ "${OS,,}" == *"debian"* ]]; then
		sudo apt remove -y docker docker-engine docker.io containerd runc
		sudo apt update
		sudo apt install -y ca-certificates curl gnupg
		sudo install -m 0755 -d /etc/apt/keyrings
		sudo rm -f /etc/apt/keyrings/docker.gpg
		curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
		sudo chmod a+r /etc/apt/keyrings/docker.gpg
		echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
		sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
		sudo apt update
		sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin wget git uuid-runtime
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
		sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin wget git uuid-runtime
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
		sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin wget git uuid-runtime
		sudo systemctl start docker
		sudo systemctl enable docker
	elif [[ "${OS,,}" == *"arch"* ]]; then
		sudo pacman -Syy && sudo pacman -S --noconfirm docker docker-compose wget git
	else
		echo "Unsupported operating system"
		exit 1
	fi

	sudo usermod -a -G docker $USER
}

function prepare_config {
	echo "setting up config..."
	if [ ! -f "./docker-compose.yml" ]; then
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

	pwd
	# set up timezone
	ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	sudo timedatectl set-timezone Asia/Shanghai

	# set up docker-compose.yml
	cp -f ./docker-compose.yml.sample ./docker-compose.yml

	# set up haproxy haproxy.cfg
	cp -f ./config/haproxy/haproxy.cfg.sample ./config/haproxy/haproxy.cfg
	sed -i "s/<your-ocserv-domain>/${OCSERV_DOMAIN}/g" ./config/haproxy/haproxy.cfg
	sed -i "s/<your-v2ray-domain>/${V2RAY_DOMAIN}/g" ./config/haproxy/haproxy.cfg

	# set up v2ray config.json
	cp -f ./config/v2ray/config.json.sample ./config/v2ray/config.json
	sed -i "s/<your-host-ip>/$(curl -s https://ifconfig.me)/g" ./config/v2ray/config.json
	sed -i "s/<your-v2ray-domain>/${V2RAY_DOMAIN}/g" ./config/v2ray/config.json
	sed -i "s/<your-uuid>/$(uuidgen)/g" ./config/v2ray/config.json
	# download latest geoip.dat and geosite.dat to ./geodata directory
	mkdir -p ./config/geodata
	wget -P ./config/geodata https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
	wget -P ./config/geodata https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat

	# set up ocserv config
	# after certs is generated, there's only one group of certs, all subdomains are included
	# and the certs directory name is the first subdomain
	cp -f ./config/ocserv/ocserv.conf.sample ./config/ocserv/ocserv.conf
	sed -i "s/<your-ocserv-domain>/${V2RAY_DOMAIN}/g" ./config/ocserv/ocserv.conf
}

function start_containers {
	echo "starting containers..."
	sg docker -c "
	docker compose up -d
	"
  sudo docker compose restart
}

function cleanup {
	if [ -f "../setup.sh" ]; then
		rm ../setup.sh
	fi
	echo ""
	echo "Install Finished"
}

function install_all {
	cd_script_dir
	check_os_release
	input_info
	prepare_sysconfig
	prepare_os_env
	prepare_config
	start_containers
	cleanup
}

function upgrade {
	cd_script_dir
	if [ ! -f "./docker-compose.yml" ]; then
		cd ladder
	fi
	git stash && git fetch && git pull
	sudo docker pull v2fly/v2fly-core
	sudo docker pull duckduckio/ocserv
	sudo docker compose up -d v2ray ocserv --force-recreate
	sudo docker image prune -f
}

function stop {
	cd_script_dir
	if [ ! -f "./docker-compose.yml" ]; then
		cd ladder
	fi
	sudo docker compose stop
}

function remove {
	cd_script_dir
	if [ ! -f "./docker-compose.yml" ]; then
		cd ladder
	fi
	sudo docker compose down
	sudo docker image prune -f
}

function help {
	echo "Usage: setup.sh [OPTION]..."
	echo "Setup V2Ray and OpenConnect on Linux"
	echo ""
	echo "  -i, --install	install V2Ray and OpenConnect"
	echo "  -u, --upgrade	upgrade V2Ray and OpenConnect"
	echo "  -r, --run		run V2Ray and OpenConnect"
	echo "  -s, --stop		stop V2Ray and OpenConnect"
	echo "  -c, --clean		stop & clean V2Ray and OpenConnect"
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
		-r|--run)
			start_containers
			;;
		-s|--stop)
			stop
			;;
		-c|--clean|--uninstall|--remove)
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
