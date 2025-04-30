#!/bin/bash


CLEANUP_INTERVAL=${CLEANUP_INTERVAL:-6}
DAEMON_DELAY=${DAEMON_DELAY:-3}
PROXY_MODE=${PROXY_MODE:-proxy}

# add cron task to clean warp logs
echo "0 */$CLEANUP_INTERVAL * * * rm -rf /var/lib/cloudflare/*.txt /var/lib/cloudflare/crash_reports/" > /etc/cron.d/cleanup_warp_log
chmod 0644 /etc/cron.d/cleanup_warp_log
crontab /etc/cron.d/cleanup_warp_log

# start cron and dbus daemon
service cron start
service dbus start


echo "------------ svc start ------------"
# start warp-svc daemon in &
# nohup warp-svc > /dev/null 2>&1 &
warp-svc &

sleep $DAEMON_DELAY

# warp-cli register
if [ ! -f "/var/lib/cloudflare-warp/reg.json" ]; then
	# register_warp.exp
	echo "------------ register ------------"
	warp-cli --accept-tos registration new
fi

if [[ -n "$WARP_KEY" ]]; then
	echo "------------ set-license ------------"
	warp-cli --accept-tos registration license $WARP_KEY
fi

# warp-cli default mode is warp which will change the network
echo "------------ set-proxy-mode ------------"
warp-cli --accept-tos mode proxy

echo "------------ start connect ------------"
# exec "$@"
warp-cli --accept-tos connect

# keep container running: tail -f /dev/null
if ip -6 addr | grep -q "scope global"; then
	socat TCP6-LISTEN:40001,reuseaddr,fork TCP6:127.0.0.1:40000
else
	socat TCP-LISTEN:40001,reuseaddr,fork TCP:127.0.0.1:40000
fi
