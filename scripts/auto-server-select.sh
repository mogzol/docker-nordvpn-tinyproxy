#! /usr/bin/env bash
# shellcheck disable=SC2236
# SC2236 is a stylistic issue that does not affect correctness and is invalid for inverting a variable check "! -z ${VAR+x}"

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

SERVER=""

nordRegion=()
# Ukraine
nordRegion+=("225")
# Poland (not ad-free)
# nordRegion+=("174")
# Moldova
nordRegion+=("142")
# Albania
nordRegion+=("2")
# Romania
nordRegion+=("179")
# Bulgaria
nordRegion+=("33")
# Latvia
nordRegion+=("119")
# Lithuania
nordRegion+=("125")
# Serbia
nordRegion+=("192")
# Israel
nordRegion+=("105")
# Luxembourg (not ad-free)
# nordRegion+=("126")

vpnType=()
# UDP
vpnType+=("3")
# TCP
vpnType+=("5")

LIMIT=1
while [ "${LIMIT}" -le 10 ]; do
  ((LIMIT++))
  # select random region
  REGION=${nordRegion[ $RANDOM % ${#nordRegion[@]} ]}

  # select random udp/tcp server
  VPN_TYPE=${vpnType[ $RANDOM % ${#vpnType[@]} ]}
  if [ "${VPN_TYPE}" = 3 ]; then
    JQ_SELECTOR='[.[] | select(.technologies[] | .identifier == "openvpn_udp")][0] | .hostname'
  else
    JQ_SELECTOR='[.[] | select(.technologies[] | .identifier == "openvpn_tcp")][0] | .hostname'
  fi

  # create nordvpn server query
  if ! URL=$(printf 'https://nordvpn.com/wp-admin/admin-ajax.php?action=servers_recommendations&filters=\{%%22country_id%%22:%d,%%22servers_technologies%%22:\[%d\]\}' "${REGION}" "${VPN_TYPE}"); then
    do_fatal "Unable to generate nordvpn server url"
  fi

  # get nordvpn server
  if SERVER=$(curl --fail --location --silent "${URL}" | jq --raw-output "${JQ_SELECTOR}"); then
    printf 'NORDVPN_SERVER="%s"\n' "${SERVER}" > /tmp/auto-selected-server

    if [ "${VPN_TYPE}" = 3 ]; then
      printf 'VPN_TYPE="%s"\n' "udp" >> /tmp/auto-selected-server
    else
      printf 'VON_TYPE="%s"\n' "tcp" >> /tmp/auto-selected-server
    fi
    
    do_info "Random server written to: /tmp/auto-selected-server"
    break
  else
    do_warn "Unable to generate nordvpn server, retrying"
  fi
done

if [ -z ${SERVER+x} ]; then
  do_error "Unable to get random server"
fi
