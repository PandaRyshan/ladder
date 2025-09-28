#!/bin/bash

trap 'clear; exit' SIGINT

# 检查是否以 root 身份运行或以 sudo 权限运行
if [ "$EUID" -ne 0 ] && [ -z "$SUDO_USER" ]; then
  echo "请以 root 身份或使用 sudo 运行此脚本"
  exit 1
fi

MAIN_MENU=1
DEPLOY_MENU=2
V2RAY_CONFIG_MENU=3
WARP_CONFIG_MENU=4
SMOKEPING_CONFIG_MENU=5
SYSCTL_MENU=6

# 统一对话框封装与校验函数
run_menu_dialog() {
    local __outvar="$1"; shift
    local __result
    __result=$(dialog "$@" 3>&1 1>&2 2>&3)
    local __status=$?
    eval "$__outvar=\"$__result\""
    exit_operation $__status
    return $__status
}

run_prompt_dialog() {
    local __outvar="$1"; shift
    local __result
    __result=$(dialog "$@" 3>&1 1>&2 2>&3)
    local __status=$?
    eval "$__outvar=\"$__result\""
    return $__status
}

run_yesno_with_prev() {
    # 用于带 Previous 按钮的 yes/no，对 3/255 交给 exit_operation，其它返回状态码
    local __status
    dialog "$@" 3>&1 1>&2 2>&3
    __status=$?
    if [ $__status -eq 3 ] || [ $__status -eq 255 ]; then
        exit_operation $__status
    fi
    return $__status
}

validate_domain() {
    local domain="$1"
    [[ -z "$domain" ]] && return 1
    if [[ "$domain" =~ ^([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

show_error() {
    local msg="$1"
    dialog --msgbox "$msg" 7 60
}

V2RAY=1
WARP=2
OPENVPN=3
SMOKEPING=4

main_menu() {
    MENU_HISTORY=($MAIN_MENU)
    CURRENT_INDEX=0
    items=(
        1 "状态 Status"
        2 "添加用户 Add User"
        3 "删除用户 Del User"
        4 "部署 Deploy"
        5 "重启 Restart"
        6 "更新 Upgrade"
        7 "停止 Stop"
        8 "卸载 Uninstall"
    )
    while true; do
        run_menu_dialog choice --clear \
            --title "主菜单" \
            --menu "请选择一个选项：" 15 50 5 \
            "${items[@]}" \
            3>&1 1>&2 2>&3

        case $choice in
            1) status_menu ;;
            2) add_user;;
            3) del_user;;
            4) deploy_menu;;
            5) restart_containers ;;
            6) upgrade_containers ;;
            7) stop_containers ;;
            8) down_containers ;;
            *) ;;
        esac
    done
}

status_menu() {
    docker compose ps 2>&1 | dialog --title "容器状态" --programbox 20 70
}

add_user() {
    while true; do
        dialog_args=(
            --title "添加用户" \
            --mixedform "用户名与密码：" 15 60 5 \
            "用户:" 1 1 "$USERNAME" 1 13 40 40 0 \
            "密码:" 2 1 "$PASSWORD" 2 13 40 40 0
        )

        result=$(dialog "${dialog_args[@]}" 3>&1 1>&2 2>&3)
        USERNAME=$(sed -n '1p' <<< "$result")
        PASSWORD=$(sed -n '2p' <<< "$result")

        if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
            dialog --msgbox "账号密码均为必填" 7 50
        else
            {
                mkdir -p config/www/conf/
                touch config/nginx/.htpasswd
                /usr/bin/expect << EOF
                spawn docker compose exec nginx htpasswd /config/nginx/.htpasswd $USERNAME
                expect "New password"
                send "$PASSWORD\r"
                expect "Re-type new password"
                send "$PASSWORD\r"
                expect eof
EOF
                docker compose exec openvpn clientgen $USERNAME 2>&1
                cp ./config/openvpn/clients/$USERNAME.ovpn ./config/www/conf/
                UUID=$(uuidgen)
                jq --arg new_user_uuid "$UUID" \
                    '.inbounds[].settings.clients += [{"id": $new_user_uuid}]' \
                    ./config/v2ray/config.json > ./config/v2ray/config.json.tmp
                mv ./config/v2ray/config.json.tmp ./config/v2ray/config.json
                echo "重启 V2Ray 服务 Restarting V2Ray service..."
                docker compose restart v2ray 2>&1
                CFG_DOMAIN=$(cat .env | grep CFG_DOMAIN | cut -d '=' -f2)
                echo ""
                echo "用户 $USERNAME 添加成功"
                echo "UUID: $new_user_uuid"
                if [[ -n "$CFG_DOMAIN" ]]; then
                    echo "OpenVPN 配置导入/下载: https://$CFG_DOMAIN/rest/GetUserlogin"
                else
                    echo "OpenVPN 配置下载: https://${PRX_DOMAIN}/conf/<your-user-name>.ovpn"
                fi
                echo "$USERNAME:$PASSWORD:$UUID" >> users.txt
            } | dialog --title "创建用户..." --programbox 20 70
            break
        fi
    done
}

del_user() {
    while true; do
        USERNAMES=$(awk -F: '{print $1}' users.txt)
        items=()
        for USERNAME in $USERNAMES; do
            items+=("$USERNAME" "" off)
        done
        run_menu_dialog CHOICES --clear \
            --title "删除用户" \
            --extra-button --extra-label "Previous" \
            --checklist "请选择要删除的用户：" 15 50 5 \
            "${items[@]}" \
            3>&1 1>&2 2>&3

        status=$?
        if [ $status -eq 3 ]; then
            return
        elif [ $status -eq 255 ]; then
            continue
        fi

        if [ -z "$CHOICES" ]; then
            dialog --msgbox "请至少选择一项" 7 50
        else
            dialog --yesno "确认删除选中的用户吗？" 7 50
            if [ $? -eq 0 ]; then
                {
                    for choice in $CHOICES; do
                        echo "删除用户 $choice"
                        sed -i "/$choice/d" ./config/nginx/.htpasswd
                        docker compose exec openvpn clientrevoke $choice 2>&1
                        UUID=$(grep -w "$choice" users.txt | cut -d ':' -f3)
                        jq --arg user "$UUID" \
                            '.inbounds[].settings.clients -= [{"id": $user}]' \
                            ./config/v2ray/config.json > ./config/v2ray/config.json.tmp
                        mv ./config/v2ray/config.json.tmp ./config/v2ray/config.json
                        sed -i "/$choice/d" users.txt
                    done
                } | dialog --title "正在删除... Del Users..." --programbox 30 100
            fi
        fi
    done
}

deploy_menu() {
    MENU_HISTORY=($MAIN_MENU $DEPLOY_MENU)
    CURRENT_INDEX=1
    while true; do
        run_menu_dialog DEPLOY_CHOICES --clear \
            --title "选择要部署的组件" \
            --extra-button --extra-label "Previous" \
            --checklist "请使用空格选择至少一个选项：" 15 50 5 \
            $V2RAY "V2Ray" on \
            $SS "Shadowsocks" off \
            $WARP "Warp" off \
            $OPENVPN "OpenVPN" off \
            $GOST "Gost" off \
            $SMOKEPING "SmokePing" off \
            3>&1 1>&2 2>&3

        status=$?
        if [ $status -eq 3 ]; then
            return
        elif [ $status -eq 255 ]; then
            continue
        fi

        if [ -z "$DEPLOY_CHOICES" ]; then
            dialog --msgbox "请至少选择一项" 7 50
        else
            for choice in $DEPLOY_CHOICES; do
                case $choice in
                    $V2RAY) MENU_HISTORY+=($V2RAY_CONFIG_MENU) ;;
                    $WARP) MENU_HISTORY+=($WARP_CONFIG_MENU) ;;
                    $SMOKEPING) MENU_HISTORY+=($SMOKEPING_CONFIG_MENU) ;;
                esac
            done
            MENU_HISTORY+=($SYSCTL_MENU)
            break
        fi
    done
    next_menu
}

v2ray_config_menu() {
    TIMEZONE=${1:-"${TIMEZONE:-Asia/Shanghai}"}
    PRX_DOMAIN=${2:-"${PRX_DOMAIN:-}"}
    CFG_DOMAIN=${3:-"${CFG_DOMAIN:-}"}

    while true; do
        dialog_args=(
            --title "环境配置"
            --extra-button --extra-label "Previous"
            --mixedform "请输入环境配置信息：" 15 60 5
            "时区:" 1 1 "$TIMEZONE" 1 11 40 40 0
            "代理域名:" 2 1 "$PRX_DOMAIN" 2 11 40 40 0
            "配置域名:" 3 1 "$CFG_DOMAIN" 3 11 40 40 0
        )
        local result status
        run_menu_dialog result "${dialog_args[@]}"
        status=$?
        if [ $status -eq 3 ]; then
            return
        elif [ $status -eq 255 ]; then
            continue
        fi

        TIMEZONE=$(sed -n '1p' <<< "$result")
        PRX_DOMAIN=$(sed -n '2p' <<< "$result")
        CFG_DOMAIN=$(sed -n '3p' <<< "$result")

        if [ -z "$TIMEZONE" ]; then
            show_error "时区必须填写。"
            continue
        fi
        if ! validate_domain "$PRX_DOMAIN"; then
            show_error "代理域名格式不正确，请输入有效域名（例如：example.com）。"
            continue
        fi
        if [[ -n "$CFG_DOMAIN" ]] && ! validate_domain "$CFG_DOMAIN"; then
            show_error "配置域名格式不正确，请输入有效域名。"
            continue
        fi
        break
    done

    while true; do
        local yn_status yn_result
        run_prompt_dialog yn_result --defaultno --yesno "是否配置出站 socks5?" 7 50
        yn_status=$?
        if [ $yn_status -eq 0 ]; then
            ENABLE_SOCKS5="true"
            dialog_args=(
                --title "SOCKS5 配置"
                --extra-button --extra-label "Previous"
                --mixedform "请输入 SOCKS5 认证信息：" 15 60 5
                "地址:" 1 1 "$SOCKS5_ADDR" 1 10 40 40 0
                "用户:" 2 1 "$SOCKS5_USER" 2 10 40 40 0
                "密码:" 3 1 "$SOCKS5_PASS" 3 10 40 40 0
            )
            local s5_result s5_status
            run_menu_dialog s5_result "${dialog_args[@]}"
            s5_status=$?
            if [ $s5_status -eq 3 ]; then
                return
            elif [ $s5_status -eq 255 ]; then
                continue
            fi
            SOCKS5_ADDR=$(sed -n '1p' <<< "$s5_result")
            SOCKS5_USER=$(sed -n '2p' <<< "$s5_result")
            SOCKS5_PASS=$(sed -n '3p' <<< "$s5_result")
            if [ -z "$SOCKS5_USER" ] || [ -z "$SOCKS5_PASS" ]; then
                show_error "必须输入认证信息以启用 Socks5。"
                continue
            fi
            break
        elif [ $yn_status -eq 255 ]; then
            continue
        else
            ENABLE_SOCKS5="false"
            break
        fi
    done
    next_menu
}

warp_config_menu() {
    WARP_KEY=${1:-"$WARP_KEY"}
    if [[ $DEPLOY_CHOICES == *"$WARP"* ]]; then
        while true; do
            dialog_args=(
                --title "Warp 配置"
                --extra-button --extra-label "Previous"
                --mixedform "请输入环境配置信息：" 15 60 5
                "Warp 密钥:" 1 1 "$WARP_KEY" 1 12 40 40 0
            )
            local result status
            run_menu_dialog result "${dialog_args[@]}"
            status=$?
            if [ $status -eq 3 ]; then
                return
            elif [ $status -eq 255 ]; then
                continue
            fi
            WARP_KEY=$(sed -n '1p' <<< "$result")
            break
        done
    fi
    next_menu
}

smokeping_config_menu() {
    HOST_NAME=${1:-"$HOST_NAME"}
    MASTER_URL=${2:-"$MASTER_URL"}
    SHARED_SECRET=${3:-"$SHARED_SECRET"}
    if [[ $DEPLOY_CHOICES == *"$SMOKEPING"* ]]; then
        while true; do
            dialog_args=(
                --title "Smokeping 配置"
                --extra-button --extra-label "Previous"
                --mixedform "请输入环境配置信息：" 15 60 5
                "本地主机名:" 1 1 "$HOST_NAME" 1 14 40 40 0
                "Master 地址:" 2 1 "$MASTER_URL" 2 14 40 40 0
                "Master 密钥:" 3 1 "$SHARED_SECRET" 3 14 40 40 0
            )
            local result status
            run_menu_dialog result "${dialog_args[@]}"
            status=$?
            if [ $status -eq 3 ]; then
                return
            elif [ $status -eq 255 ]; then
                continue
            fi
            HOST_NAME=$(sed -n '1p' <<< "$result")
            MASTER_URL=$(sed -n '2p' <<< "$result")
            SHARED_SECRET=$(sed -n '3p' <<< "$result")
            if [ -z "$HOST_NAME" ]; then
                show_error "本地主机名为必填项。"
                continue
            fi
            if [[ -n "$MASTER_URL" ]] && [ -z "$SHARED_SECRET" ]; then
                show_error "当配置 Master 地址时，必须同时填写 Master 密钥。"
                continue
            fi
            break
        done
    fi
    next_menu
}

sysctl_menu() {
    while true; do
        run_yesno_with_prev --clear \
            --title "优化 sysctl.conf" \
            --extra-button --extra-label "Previous" \
            --yesno "是否优化 sysctl.conf?" 7 50
        status=$?
        if [ $status -eq 0 ]; then
            SYSCTL_OPTIMIZE=0
        elif [ $status -eq 1 ]; then
            SYSCTL_OPTIMIZE=1
        elif [ $status -eq 3 ]; then
            return
        elif [ $status -eq 255 ]; then
            continue
        fi

        run_prompt_dialog _ --yesno "确认开始部署？" 7 50
        dstatus=$?
        if [ $dstatus -eq 0 ]; then
            deploy
            break
        elif [ $dstatus -eq 255 ]; then
            continue
        else
            continue
        fi
    done
}

previous_menu() {
    if [ ${#MENU_HISTORY[@]} -gt 1 ]; then
        CURRENT_INDEX=$(($CURRENT_INDEX - 1))
        PREVIOUS_MENU=${MENU_HISTORY[$CURRENT_INDEX]}
    else
        PREVIOUS_MENU=$MAIN_MENU
    fi
    case $PREVIOUS_MENU in
        1) main_menu ;;
        2) deploy_menu ;;
        3) v2ray_config_menu $TIMEZONE $PRX_DOMAIN $CFG_DOMAIN ;;
        4) warp_config_menu $WARP_KEY ;;
        5) smokeping_config_menu $HOST_NAME $MASTER_URL $SHARED_SECRET ;;
        6) sysctl_menu ;;
    esac
}

next_menu() {
    CURRENT_INDEX=$(($CURRENT_INDEX + 1))
    NEXT_MENU=${MENU_HISTORY[$CURRENT_INDEX]}
    # dialog --msgbox "CURRENT_INDEX: $CURRENT_INDEX\nNEXT_MENU: $NEXT_MENU" 7 50
    case $NEXT_MENU in
        1) main_menu ;;
        2) deploy_menu ;;
        3) v2ray_config_menu $TIMEZONE $PRX_DOMAIN $CFG_DOMAIN ;;
        4) warp_config_menu $WARP_KEY ;;
        5) smokeping_config_menu $HOST_NAME $MASTER_URL $SHARED_SECRET ;;
        6) sysctl_menu ;;
    esac
}

exit_operation() {
    exit_status=$1
    case $exit_status in
        # Cancel
        1) clear; exit 0 ;;
        # Previous
        3) previous_menu; return ;;
        # ESC
        255)
            dialog --yesno "是否要退出？" 7 50
            if [ $? -eq 0 ]; then
                clear
                exit 0
            else
                return
            fi
    esac
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
        if [[ "$DEPLOY_CHOICES" == *"$OPENVPN"* ]]; then
            check_tun_device
        fi
        check_docker_env
        enable_docker_ipv6
        sysctl_config
        env_config
        docker_compose_config
        v2ray_config
        haproxy_config
        nginx_config
}

check_tun_device() {
    if [ ! -c /dev/net/tun ]; then
        echo "创建 TUN 设备 Creating TUN device..."
        mkdir -p /dev/net
        mknod /dev/net/tun c 10 200
        chmod 600 /dev/net/tun
    fi
}

check_os_release() {
    echo "检查发行版 Checking os release..."
    if [ -f "/etc/os-release" ]; then
        . /etc/os-release
        OS=$NAME
    fi
}

install_missing_packages() {
    if ! command -v dialog &> /dev/null \
        || ! command -v uuidgen &> /dev/null \
        || ! command -v expect &> /dev/null \
        || ! command -v jq &> /dev/null
    then
        echo "安装 dialog"
        if [[ "${OS,,}" == *"debian"* ]] || [[ "${OS,,}" == *"ubuntu"* ]]; then
            apt-get update && apt-get install -y dialog util-linux uuid-runtime expect jq
        elif [[ "${OS,,}" == *"centos"* ]] || [[ "${OS,,}" == *"fedora"* ]]; then
            dnf install -y dialog util-linux expect jq
        elif [[ "${OS,,}" == *"arch"* ]]; then
            pacman -Sy --noconfirm dialog util-linux expect jq
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
    mkdir -p /etc/docker
    cat <<- EOF > /etc/docker/daemon.json
{
    "experimental": true,
    "ip6tables": true
}
EOF

    if [[ "${OS,,}" == *"ubuntu"* ]]; then
        # Uninstall conflicting packages:
        for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do apt-get remove $pkg; done;
        apt-get update
        apt-get install -y ca-certificates curl
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc

        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif [[ "${OS,,}" == *"debian"* ]]; then
        for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do apt-get remove $pkg; done
        apt-get update
        apt-get install -y ca-certificates curl uuid-runtime
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc

        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif [[ "${OS,,}" == *"centos"* ]]; then
        yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
        yum install -y yum-utils util-linux
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    elif [[ "${OS,,}" == *"fedora"* ]]; then
        dnf remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine
        dnf install -y dnf-plugins-core util-linux
        dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    elif [[ "${OS,,}" == *"arch"* ]]; then
        pacman -Syy && pacman -S --noconfirm docker docker-compose util-linux
    else
        echo "Unsupported operating system"
        exit 1
    fi

    usermod -a -G docker $USER
    enable_docker_service
}

enable_docker_service() {
    systemctl enable docker 2>&1
    systemctl start docker 2>&1
}

enable_docker_ipv6() {
    if [ ! -f "/etc/docker/daemon.json" ] || [ ! -s "/etc/docker/daemon.json" ]; then
        mkdir -p /etc/docker
        tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "experimental": true,
    "ip6tables": true
}
EOF
    else
        content=$(cat /etc/docker/daemon.json)
        if [[ ! $content =~ \{.*\} ]]; then
            tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "experimental": true,
    "ip6tables": true
}
EOF
        else
            if ! grep -q "experimental" /etc/docker/daemon.json; then
                sed -i 's/^{/{\n    "experimental": true,/' /etc/docker/daemon.json
            fi
            if ! grep -q "ip6tables" /etc/docker/daemon.json; then
                sed -i 's/^{/{\n    "ip6tables": true,/' /etc/docker/daemon.json
            fi
            sed -i 's/,\s*}/\n}/' /etc/docker/daemon.json
        fi
    fi
}

sysctl_config() {
    if [[ "$SYSCTL_OPTIMIZE" == 0 ]]; then
        echo "优化网络设置 Updating sysctl config..."
        if ! grep -q "* soft nofile 51200" /etc/security/limits.conf; then
            tee -a /etc/security/limits.conf <<- EOF
* soft nofile 51200
* hard nofile 51200

root soft nofile 51200
root hard nofile 51200
EOF
        fi

        mkdir -p /etc/sysctl.d/
        tee /etc/sysctl.d/50-network.conf <<- EOF
fs.file-max = 51200

net.ipv4_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_mtu_probing = 2
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_retries2 = 3
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_tw_buckets = 5000
net.core.netdev_max_backlog = 500000
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 8192

net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 131072 8388608
net.ipv4.tcp_wmem = 4096 87380 8388608
#net.ipv4.tcp_wmem = 4096 65536 8388608
net.ipv4.tcp_mem = 262144 393216 524288

net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

        ulimit -n 51200
        sysctl --system
    fi
}

env_config() {
    cat <<- EOF > .env
TIMEZONE=${TIMEZONE}
PRX_DOMAIN=${PRX_DOMAIN}
CFG_DOMAIN=${CFG_DOMAIN}

# warp plus key
WARP_KEY=${WARP_KEY}

# smokeping config
HOST_NAME=${HOST_NAME}
MASTER_URL=${MASTER_URL}
SHARED_SECRET=${SHARED_SECRET}

# for notification
EMAIL=${EMAIL}
EOF
}

docker_compose_config() {
    if [[ "$DEPLOY_CHOICES" == *"$V2RAY"* ]]; then
        echo "下载 geodata. Downloading geodata..."
        mkdir -p ./config/geodata
        curl -sLo ./config/geodata/geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
        curl -sLo ./config/geodata/geosite.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
    fi

    echo "写入 docker 配置. Writing docker-compose config..."
    cat <<- EOF > docker-compose.yaml
services:

  haproxy:
    image: haproxy:latest
    container_name: haproxy
    volumes:
      - ./config/haproxy/haproxy.tcp.cfg:/usr/local/etc/haproxy/haproxy.cfg
      - ./config/certs/live/\${PRX_DOMAIN}:/etc/ssl/certs
    networks:
      - ipv6
    ports:
      - 443:443/tcp
      - 11443:443/tcp
    restart: unless-stopped

  nginx:
    image: linuxserver/swag:latest
    container_name: nginx
    cap_add:
      - NET_ADMIN
    environment:
      - PUID=99
      - PGID=99
      - TZ=\${TIMEZONE}
      - URL=\${PRX_DOMAIN}
      - EXTRA_DOMAINS=\${CFG_DOMAIN}
      - VALIDATION=http
      - EMAIL=\${EMAIL}
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

    if [[ "$DEPLOY_CHOICES" == *"$V2RAY"* ]]; then
        cat <<- EOF >> docker-compose.yaml
  v2ray:
    image: ghcr.io/pandaryshan/v2ray:latest
    container_name: v2ray
    environment:
      - WAIT_PATHS=/etc/ssl/certs/v2ray/priv-fullchain-bundle.pem
    volumes:
      - ./config/v2ray/config.json:/etc/v2ray/config.json
      - ./config/geodata:/usr/share/v2ray
      - ./config/certs/live/\${PRX_DOMAIN}:/etc/ssl/certs/v2ray
    networks:
      - ipv6
    restart: unless-stopped

EOF
    fi

    if [[ "$DEPLOY_CHOICES" == *"$SS"* ]]; then
        cat <<- EOF >> docker-compose.yaml
  ss:
    image: ghcr.io/pandaryshan/shadowsocks:latest
    container_name: ss
    environment:
      - SERVER_PORT=8388
      - METHOD="2022-blake3-chacha20-poly1305"
      - PASSWORD=      # Optional
    networks:
      - ipv6
    ports:
      - 17443:8388/tcp
    volumes:
      - ./config/ss:/etc/shadowsocks
    restart: unless-stopped

EOF
    fi

    if [[ "$DEPLOY_CHOICES" == *"$WARP"* ]]; then
        cat <<- EOF >> docker-compose.yaml
  warp:
    image: ghcr.io/pandaryshan/warp:latest
    container_name: warp
    environment:
      - WARP_KEY=\${WARP_KEY}
    volumes:
      - ./config/warp:/var/lib/cloudflare-warp
    networks:
      - ipv6
    restart: unless-stopped

EOF
    fi

    if [[ "$DEPLOY_CHOICES" == *"$OPENVPN"* ]]; then
        cat <<- EOF >> docker-compose.yaml
  openvpn:
    image: ghcr.io/pandaryshan/openvpn:latest
    container_name: openvpn
    environment:
      - DOMAIN=\${PRX_DOMAIN}
      - FORWARD_PROXY_IPV4=\${FORWARD_PROXY_IPV4}
      - FORWARD_PROXY_IPV6=\${FORWARD_PROXY_IPV6}
    volumes:
      - ./config/openvpn:/etc/openvpn
    devices:
      - /dev/net/tun:/dev/net/tun
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

    if [[ "$DEPLOY_CHOICES" == *"$GOST"* ]]; then
        cat <<- EOF >> docker-compose.yaml
  gost:
    image: gogost/gost:latest
    container_name: gost
    networks:
      - ipv6
    command:
      -L "tcp://[::]:40000?sniffing=true&trpoxy=true&so_mark=100"
      -F "socks5://v2ray:7799"
    restart: unless-stopped

EOF
    fi

    if [[ "$DEPLOY_CHOICES" == *"$SMOKEPING"* ]]; then
        smokeping_config
        cat <<- EOF >> docker-compose.yaml
  smokeping:
    image: lscr.io/linuxserver/smokeping:latest
    container_name: smokeping
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Shanghai
      - MASTER_URL=\${MASTER_URL}
      - SHARED_SECRET=\${SHARED_SECRET}
    hostname: \${HOST_NAME}
    networks:
      - ipv6
    volumes:
      - ./config/smokeping:/config
      - ./data/smokeping:/data
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
    SOCKS_SERVER_USER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    SOCKS_SERVER_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
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
            "8.8.8.8",
            "1.1.1.1",
            "localhost"
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
            "tag": "socks",
            "protocol": "socks",
            "listen": "0.0.0.0",
            "port": 8002,
            "settings": {
                "address": "127.0.0.1",
                "auth": "password",
                "accounts": [
                    {
                        "user": "${SOCKS_SERVER_USER}",
                        "pass": "${SOCKS_SERVER_PASS}"
                    }
                ]
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
        }
    ],
    "outbounds": [
EOF

    if [[ "$DEPLOY_CHOICES" == *"$WARP"* ]]; then
        cat <<- EOF >> ./config/v2ray/config.json
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
EOF
    fi

    if [[ "$ENABLE_SOCKS5" == "true" ]]; then
        cat <<- EOF >> ./config/v2ray/config.json
        {
            "tag": "socks",
            "protocol": "socks",
            "settings": {
                "servers": [
                    {
                        "address": "${SOCKS5_ADDR}",
                        "port": 443,
                        "users": [{
                            "user": "${SOCKS5_USER}",
                            "pass": "${SOCKS5_PASS}"
                        }]
                    }
                ]
            }
        },
EOF
    fi

    cat <<- EOF >> ./config/v2ray/config.json
        {
            "tag": "blocked",
            "protocol": "blackhole"
        },
        {
            "tag": "freedom",
            "protocol": "freedom"
        }
    ],
    "routing": {
        "domainStrategy": "AsIs",
        "domainMatcher": "mph",
        "rules": [
            {
                "type": "field",
                "domain": [
                    "geosite:category-ads-all"
                ],
                "outboundTag": "blocked"
            },
            {
                "type": "field",
                "protocol": [
                    "bittorrent"
                ],
                "outboundTag": "blocked"
            },
EOF

    if [[ "$DEPLOY_CHOICES" == *"$WARP"* ]]; then
    cat <<- EOF >> ./config/v2ray/config.json
            {
                "type": "field",
                "domain": [
                    "geosite:reddit"
                ],
                "outboundTag": "cf-warp"
            },
EOF
    fi

    cat <<- EOF >> ./config/v2ray/config.json
            {
                "type": "field",
                "inboundTag": ["tcp", "grpc", "quic"],
                "outboundTag": "freedom"
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
    bind :::4433 v4v6

    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }
    tcp-request content accept if { req.payload(0,1) -m bin 05 }
EOF

    if [[ -n "$CFG_DOMAIN" ]]; then
        cat <<- EOF >> ./config/haproxy/haproxy.tcp.cfg
    tcp-request content accept if { req.ssl_sni -i ${CFG_DOMAIN} }
EOF
    fi

    cat <<- EOF >> ./config/haproxy/haproxy.tcp.cfg
    tcp-request content accept if { req.ssl_sni -i ${PRX_DOMAIN} }
    tcp-request content accept if !{ req.ssl_sni -m found }
    tcp-request content reject

EOF

    if [[ -n "$CFG_DOMAIN" ]]; then
        cat <<- EOF >> ./config/haproxy/haproxy.tcp.cfg
    acl is_config req.ssl_sni -i ${CFG_DOMAIN}
EOF
    fi

    cat <<- EOF >> ./config/haproxy/haproxy.tcp.cfg
    acl is_allowed_domain req.ssl_sni -i ${PRX_DOMAIN} ${CFG_DOMAIN}
    acl is_socks req.payload(0,1) -m bin 05
    acl is_socks_port dst_port 4433
    # acl is_http req.ssl_alpn -i http/1.1 h2
    acl has_sni req.ssl_sni -m found

EOF

    if [[ "$DEPLOY_CHOICES" == *"$V2RAY"* ]]; then
        cat <<- EOF >> ./config/haproxy/haproxy.tcp.cfg
    use_backend v2ray_socks if is_socks
    use_backend v2ray_tcp if is_allowed_domain !HTTP
EOF
    fi

    if [[ "$DEPLOY_CHOICES" == *"$OPENVPN"* ]]; then
        cat <<- EOF >> ./config/haproxy/haproxy.tcp.cfg
    use_backend openvpn if !has_sni !HTTP
EOF
    fi

    if [[ -n "$CFG_DOMAIN" ]]; then
        cat <<- EOF >> ./config/haproxy/haproxy.tcp.cfg
    use_backend nginx if is_allowed_domain HTTP
EOF
    fi

    cat <<-EOF >> ./config/haproxy/haproxy.tcp.cfg
    # default_backend nginx

backend nginx
    server nginx nginx:443

EOF

    if [[ "$DEPLOY_CHOICES" == *"$V2RAY"* ]]; then
        cat <<- EOF >> ./config/haproxy/haproxy.tcp.cfg
backend v2ray_tcp
    server v2ray v2ray:8001

backend v2ray_socks
    server v2ray v2ray:8002

EOF
    fi

    if [[ "$DEPLOY_CHOICES" == *"$OPENVPN"* ]]; then
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
## Version 2025/07/17 - https://github.com/linuxserver/docker-swag/blob/master/root/defaults/nginx/site-confs/default.conf.sample

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 444;
}

server {
    listen 80;
    listen [::]:80;
    server_name ${PRX_DOMAIN} ${CFG_DOMAIN};
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;
    return 444;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name ${PRX_DOMAIN} ${CFG_DOMAIN};

    include /config/nginx/ssl.conf;

    root /config/www;
    index index.html index.htm;

    include /config/nginx/proxy-confs/*.subfolder.conf;

    location / {
        try_files \$uri \$uri/ /index.html /index.htm;
    }

    location /conf {
        auth_basic "Restricted";
        auth_basic_user_file /config/nginx/.htpasswd;

        try_files \$uri \$uri/;
    }

    location /rest/GetUserlogin {
        auth_basic "Restricted";
        auth_basic_user_file /config/nginx/.htpasswd;

        alias /config/www/conf/;
        default_type text/plain;
        try_files \$remote_user.ovpn =404;
    }

    location /${SERVICE_NAME} {
        if ( \$content_type !~ "application/grpc") {
            return 404;
        }

        if ( \$request_method != "POST" ) {
            return 404;
        }

        include /config/nginx/proxy.conf;
        client_body_timeout 300s;
        client_max_body_size 0;
        client_body_buffer_size 32k;
        grpc_connect_timeout 10s;
        proxy_buffering off;
        grpc_read_timeout 300s;
        grpc_send_timeout 300s;
        grpc_socket_keepalive on;
        grpc_pass grpc://grpc_backend;
    }
EOF

    if [[ "$DEPLOY_CHOICES" == *"$SMOKEPING"* ]]; then
    cat <<- EOF >> ./config/nginx/site-confs/default.conf

    location ~* ^/(css|js|cache)/ {
        include /config/nginx/proxy.conf;
        rewrite ^/(js|css|cache)/(.*)$ /smokeping/\$1/\$2 break;
        proxy_pass http://smokeping:80;
    }

    location /smokeping {
        include /config/nginx/proxy.conf;
        proxy_pass http://smokeping:80/smokeping/;
    }
EOF
    fi

    cat <<- EOF >> ./config/nginx/site-confs/default.conf
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
EOF
}

smokeping_config() {
    echo "写入 SmokePing 配置... Writing SmokePing config..."
    mkdir -p ./config/smokeping
    curl -sLo ./config/smokeping/Targets https://raw.githubusercontent.com/PandaRyshan/ladder/refs/heads/main/config/smokeping/Targets
}

pull_images() {
    {
        docker compose pull 2>&1
    } | dialog --title "正在拉取镜像..." --programbox 20 70
}

up_containers() {
    {
        docker compose up -d 2>&1
    } | dialog --title "正在部署容器..." --programbox 20 70
}

start_containers() {
    {
        docker compose start 2>&1
    } | dialog --title "正在启动容器..." --programbox 20 70
}

upgrade_containers() {
    {
        docker compose pull 2>&1
    } | dialog --title "正在更新容器..." --programbox 20 70
}

stop_containers() {
    {
        docker compose stop 2>&1
    } | dialog --title "正在停止容器..." --programbox 20 70
}

restart_containers() {
    {
        docker compose restart 2>&1
    } | dialog --title "正在重启容器..." --programbox 20 70
}

down_containers() {
    {
        docker compose down 2>&1
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
    max_len=$(echo -e "${PRX_DOMAIN}\n${UUID}\n${SERVICE_NAME}" | wc -L)
    {
        echo ""
        echo "安装脚本已移动至容器配置目录：${pwd}"
        echo "V2Ray 配置："
        printf "+--------------+-%-${max_len}s-\n" | sed "s/ /-/g"
        printf "| %-12s | %-${max_len}s |\n" "Domain:" "${PRX_DOMAIN}"
        printf "| %-12s | %-${max_len}s |\n" "Protocol:" "tcp / grpc"
        printf "| %-12s | %-${max_len}s |\n" "UUID:" "${UUID}"
        printf "| %-12s | %-${max_len}s |\n" "ServiceName:" "${SERVICE_NAME}"
        printf "| %-12s | %-${max_len}s |\n" "TLS:" "Yes"
        printf "+--------------+-%-${max_len}s-\n" | sed "s/ /-/g"
        echo ""
        if [[ -n "$CFG_DOMAIN" ]]; then
            echo "OpenVPN 配置导入/下载地址 https://${CFG_DOMAIN}/rest/GetUserlogin 导入"
        else
            echo "OpenVPN 配置下载: https://${PRX_DOMAIN}/conf/<your-user-name>.ovpn"
        fi
    } | tee $(pwd)/info.txt
}

# Main 主程序
check_os_release
install_missing_packages
main_menu
clear
cat $(pwd)/info.txt
