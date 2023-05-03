#!/bin/bash

# set up timezone
# ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
sudo timedatectl set-timezone ${TZ}

# Replace <your-host-ip> with your IP address
sed -i "s/<your-host-ip>/$(curl -s https://ifconfig.me)/g" ./config/v2ray/config.json

# Download geoip.dat and geosite.dat to ./geodata directory
mkdir -p ./geodata

if ! wget -P https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat; then
    rm -f geoip.dat
    echo -e "\033[31mFailed to download geoip.dat\033[0m"
fi

if ! wget -P https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat; then
    rm -f geosite.dat
    echo -e "\033[31mFailed to download geosite.dat\033[0m"
fi

cd ..