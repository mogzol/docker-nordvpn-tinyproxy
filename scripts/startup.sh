#! /usr/bin/env sh
# shellcheck disable=SC2236
# SC2236 is a stylistic issue that does not affect correctness and is invalid for inverting a variable check "! -z ${VAR+x}"

PORT=${PORT:-8888}
OPENVPN_CREDS=${OPENVON_CREDS:-"./openvpn.pass"}
VPN_TYPE=${VPN_TYPE:-udp}
TINYPROXY_CONF=${TINYPROXY_CONF:="/etc/tinyproxy/tinyproxy.conf"}
SRC_NET=${SRC_NET:="192.168.0.0/16"}

do_fatal() {
  printf '[%b] %s\n' "\033[91mFATAL\033[0m" "${@}"
  cleanup 1
}
do_error() {
  printf '[%b] %s\n' "\033[91mERROR\033[0m" "${@}"
}
do_warn() {
  printf '[%b] %s\n' "\033[93mWARN \033[0m" "${@}"
}
do_info() {
  printf '[%b] %s\n' "\033[94mINFO \033[0m" "${@}"
}
do_pass() {
  printf '[%b] %s\n' "\033[92m OK  \033[0m" "${@}"
}

checkVars() {
  for name in USERNAME PASSWORD; do
    if [ -z "$(eval printf \'%s\' "\$$name")" ]; then
      do_fatal "Variable ${name} not set!"
    fi
  done
}

cleanup() {
  exit ${1:-0}
}

configOvpn() {
  if ! printf '%s\n' "${USERNAME}" > "${OPENVPN_CREDS}"; then
    do_fatal "Unable to write username to ${OPENVPN_CREDS}"
  fi
  if ! printf '%s\n' "${PASSWORD}" >> "${OPENVPN_CREDS}"; then
    do_fatal "Unable to write password to ${OPENVPN_CREDS}"
  fi
  do_pass "Openvpn configured"
}

configProxy() {
  if ! printf 'Port %d\n' "${PORT}" > "${TINYPROXY_CONF}"; then
    do_fatal "Unable to write proxy port configuration to ${TINYPROXY_CONF}"
  fi

  if [ -z "${PROXY_USERNAME+x}" ]; then
    do_warn "Proxy username is undefined, no credentials will be required to access the proxy!"
  elif [ -z "${PROXY_PASSWORD-z}" ]; then
    do_warn "Proxy password is undefined, no credentials will be required to access the proxy!"
  else
    do_info "Proxy credentials detected, configuring tinyproxy."
    if ! printf 'BasicAuth %s %s\n' "${PROXY_USERNAME}" "${PROXY_PASSWORD}" >> "${TINYPROXY_CONF}"; then
      do_fatal "Unable to write proxy credential configuration to ${TINYPROXY_CONF}"
    fi
  fi
  do_pass "Tinyproxy configured"
}

configRoutes() {
  # Allow tinyproxy traffic to bypass the VPN
  DEFAULT_ROUTE_RULE="$(ip route | grep default)"
  DEFAULT_ROUTE_IP="$(printf '%s' "${DEFAULT_ROUTE_RULE}" | awk '{print $3}')"
  if ! ip route add ${DEFAULT_ROUTE_RULE} table ${PORT}; then
    do_fatal "Unable to configure routing table (1 of 4)"
  fi
  if ! ip rule add iif lo ipproto tcp sport ${PORT} lookup ${PORT}; then
    do_fatal "Unable to configure routing table (2 of 4)"
  fi
  if ! ip rule add iif eth0 ipproto tcp dport ${PORT} lookup ${PORT}; then
    do_fatal "Unable to configure routing table (3 of 4)"
  fi
  if ! ip route add ${SRC_NET} via ${DEFAULT_ROUTE_IP} dev eth0; then
    do_fatal "Unable to configure routing table (4 of 4)"
  fi
  do_info "Network routes configured"
}

startOvpn() {
  if [ ! -d /dev/net ]; then
    mkdir -p /dev/net
  fi
  if ! file /dev/net/tun | grep 'character special'; then
    mknod /dev/net/tun c 10 200
  fi

  do_info "Openvpn config file: /etc/openvpn/ovpn_${VPN_TYPE}/${SERVER}.${VPN_TYPE}.ovpn"
  openvpn --config "/etc/openvpn/ovpn_${VPN_TYPE}/${SERVER}.${VPN_TYPE}.ovpn" --auth-user-pass "${OPENVPN_CREDS}"
  kill $$
}

startProxy() {
  tinyproxy -d
  kill $$
}

getRandomServer() {
  auto-server-select.sh
  if [ ! -e "/tmp/auto-selected-server" ]; then
    do_error "Auto selected server environmental file missing"
  fi

  if ! . /tmp/auto-selected-server; then
    do_error "Unable to source server environmental file"
  fi

  SERVER="${NORDVPN_SERVER}"
  if [ -z ${SERVER+x} ]; then
    do_error "Unable to set server"
  fi
  do_info "Server selected: ${SERVER}"
}

handleSig() {
  case "${1}" in
    SIGTERM|TERM|SIGINT|INT|SIGHUP|HUP)
      do_warn "Signel received: ${1}"
      cleanup 1
      ;;
    *)
      ;;
  esac
}

_trap() {
  for sig in "${@}"; do
    trap 'handleSig ${sig}' "${sig}"
  done
}

# Allow this script to exit when recieving SIGTERM, so that if either of the sub-processes die, the docker container will stop
_trap SIGTERM TERM SIGINT INT SIGHUP HUP

checkVars
if [ -z ${SERVER+x} ]; then
  getRandomServer
fi
configOvpn
configProxy
configRoutes
startOvpn & startProxy &
wait
