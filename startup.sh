#!/bin/sh

# Allow this script to exit when recieving SIGTERM, so that if either of the sub-processes die, the docker container will stop
trap "exit" SIGTERM

PORT=${PORT:-8888}

for name in USERNAME PASSWORD SERVER; do
  if [ -z "$(eval echo \$$name)" ]; then
    echo "Variable $name not set!"
    exit 1
  fi
done

startovpn() {
  echo "$USERNAME" > openvpn.pass
  echo "$PASSWORD" >> openvpn.pass
  openvpn --config /etc/openvpn/ovpn_udp/$SERVER.udp.ovpn --auth-user-pass ./openvpn.pass
  kill $$
}

startproxy() {
  echo "Port $PORT" > /etc/tinyproxy/tinyproxy.conf

  if [ -n "$PROXY_USERNAME" ] && [ -n "$PROXY_PASSWORD" ]; then
    echo "BasicAuth $PROXY_USERNAME $PROXY_PASSWORD" >> /etc/tinyproxy/tinyproxy.conf
  fi

  # Allow tinyproxy traffic to bypass the VPN
  DEFAULT_ROUTE_RULE=$(ip route | grep default)
  ip route add $DEFAULT_ROUTE_RULE table $PORT
  ip rule add iif lo ipproto tcp sport $PORT lookup $PORT
  ip rule add iif eth0 ipproto tcp dport $PORT lookup $PORT

  tinyproxy -d
  kill $$
}

startovpn & startproxy &
wait
