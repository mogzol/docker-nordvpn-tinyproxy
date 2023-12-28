#! /usr/bin/env sh
# shellcheck disable=SC2236
# SC2236 is a stylistic issue that does not affect correctness and is invalid for inverting a variable check "! -z ${VAR+x}"

# Allow this script to exit when recieving SIGTERM, so that if either of the sub-processes die, the docker container will stop
trap "exit" TERM

PORT=${PORT:-8888}
OPENVPN_CREDS=${OPENVON_CREDS:-"./openvpn.pass"}
VPN_TYPE=${VPN_TYPE:-udp}
TINYPROXY_CONF=${TINYPROXY_CONF:="/etc/tinyproxy/tinyproxy.conf"}

do_fatal() {
  printf '[%b] %s\n' "\033[91mFATAL\033[0m" "${@}"
  exit 100
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

configOvpn() {
  if ! printf '%s\n' "${USERNAME}" > ${OPENVPN_CREDS}; then
    do_fatal "Unable to write username to ${OPENVPN_CREDS}"
  fi
  if ! printf '%s\n' "${PASSWORD}" >> ${OPENVPN_CREDS}; then
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
  if ! ip route add "${DEFAULT_ROUTE_RULE}" table "${PORT}"; then
    do_fatal "Unable to configure routing table (1 of 3)"
  fi
  if ! ip rule add iif lo ipproto tcp sport "${PORT}" lookup "${PORT}"; then
    do_fatal "Unable to configure routing table (2 of 3)"
  fi
  if ! ip rule add iif eth0 ipproto tcp dport "${PORT}" lookup "${PORT}"; then
    do_fatal "Unable to configure routing table (3 of 3)"
  fi
}

startOvpn() {
  do_info "Openvpn config file: /etc/openvpn/ovpn_${VPN_TYPE}/${SERVER}.${VPN_TYPE}.ovpn"
  openvpn --config "/etc/openvpn/ovpn_${VPN_TYPE}/${SERVER}.${VPN_TYPE}.ovpn" --auth-user-pass "${OPENVPN_CREDS}"
  kill $$
}

startProxy() {
  tinyproxy -d
  kill $$

  configRoutes
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

while [ ${#} -gt 0 ]; do
  case "${1}" in
    -D|--debug)
      set -x
      shift;;
    -p|--port)
      if printf '%s' "${2}" | grep -E -q '^\d+$'; then
        PORT="${2}"
      else
        do_warn "Port is not numeric, using default: $PORT"
      fi
      shift; shift;;
    -o|--ovpn-config)
      if [ ! -z ${2+x} ] && [ "${2}" != "" ]; then
        OPENVPN_CREDS="${2}"
      else
        do_warn "Unable to use provided openvpn config file, using default: ${OPENVPN_CREDS}"
      fi
      shift; shift;;
    -t|--tproxy-config)
      if [ ! -z ${2+x} ] && [ "${2}" != "" ]; then
        TINYPROXY_CONF="${2}"
      else
        do_warn "Unable to use provided tinyproxy config file, using default: ${TINYPROXY_CONF}"
      fi
      shift; shift;;
    --nord-username)
      if [ ! -z ${2+x} ] && [ "${2}" != "" ]; then
        USERNAME="${2}"
      else
        do_warn "Unable to use provided tinyproxy username, using environment variable"
      fi
      shift; shift;;
    --nord-password)
      if [ ! -z ${2+x} ] && [ "${2}" != "" ]; then
        PASSWORD="${2}"
      else
        do_warn "Unable to use provided tinyproxy username, using environment variable"
      fi
      shift; shift;;
    --proxy-username)
      if [ ! -z ${2+x} ] && [ "${2}" != "" ]; then
        PROXY_USERNAME="${2}"
      else
        do_warn "Unable to use provided tinyproxy username, using environment variable"
      fi
      shift; shift;;
    --proxy-password)
      if [ ! -z ${2+x} ] && [ "${2}" != "" ]; then
        PROXY_PASSWORD="${2}"
      else
        do_warn "Unable to use provided tinyproxy password, using environment variable"
      fi
      shift; shift;;
    -s|--server)
      if [ ! -z ${2+x} ] && [ "${2}" != "" ]; then
        SERVER="${2}"
      else
        do_warn "Unable to use provided server, using auto-selected server"
      fi
      shift; shift;;
    esac
done

checkVars
if [ -z ${SERVER+x} ]; then
  getRandomServer
fi
configOvpn
configProxy
startOvpn & startProxy &
wait
