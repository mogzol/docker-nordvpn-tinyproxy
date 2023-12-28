#! /usr/bin/env sh
# shellcheck disable=SC2236
# SC2236 is a stylistic issue that does not affect correctness and is invalid for inverting a variable check "! -z ${VAR+x}"

STORE_REMOTE_IP="false"

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

getPublicIP() {
  ip=""

  # curl lookups
  for i in "https://icanhazip.com" "https://ifconfig.me" "https://api.ipify.org" "https://bot.whatismyipaddress.com" "https://ipinfo.io/ip" "https://ipecho.net/plain"; do
    if ip=$(curl --fail --silent "${i}") && [ ! -z ${ip+x} ]; then
      printf '%s' "${ip}"
      return 0
    fi
  done

  # DNS Lookups
  if ip=$(dig -4 @ns1.google.com TXT o-o.myaddr.l.google.com +short | sed -e 's/"//g') && [ ! -z ${ip+x} ]; then
    printf '%s' "${ip}"
    return 0
  fi

  if ip=$(dig -4 @resolver1.opendns.com A myip.opendns.com +short | sed -e 's/"//g') && [ ! -z ${ip+x} ]; then
    printf '%s' "${ip}"
    return 0
  fi

  if ip=$(dig -4 @1.0.0.1 txt ch whoami.cloudflare +short | sed -e 's/"//g') && [ ! -z ${ip+x} ]; then
    printf '%s' "${ip}"
    return 0
  fi

  return 100
}

while [ ${#} -gt 0 ]; do
  case "${1}" in
    -D|--debug)
      set -x
      shift;;
    -s|--store)
      STORE_REMOTE_IP="true"
      shift;;
  esac
done

# get current external IP
if DIP=$(getPublicIP); then
  do_fatal "Unable to detect real-world IP."
fi
# Make sure there is data in the variable
if [ -z ${DIP+x} ]; then
  do_fatal "Unable to detect real-world IP."
fi

if [ ${STORE_REMOTE_IP} = "true" ]; then
  if ! printf 'REMOTE_IP="%s"\n' "${DIP}" > /tmp/preserved-ip; then
    do_fatal "Unable to store ip to file: /tmp/preserved-ip"
  fi
  do_pass "Current public ip: ${DIP}"
else
  if [ ! -e "/tmp/preserved-ip" ]; then
    do_fatal "Unable to read original IP for comparison"
  fi
  if ! . /tmp/preserved-ip; then
    do_fatal "Unable to read stored ip from file: /tmp/preserved-ip"
  fi
  if [ -z ${REMOTE_IP+x} ]; then
    do_fatal "Unable to read stored ip from file: /tmp/preserved-ip"
  fi
  do_info "Original ip: ${REMOTE_IP}"
  do_info "Current ip:  ${DIP}"
  if [ "$(printf '%s' "${REMOTE_IP}" | sed -r -e 's/^(\d+).*$/\1/p')" = "$(printf '%s' "${DIP}" | sed -r -e 's/^(\d+).*$/\1/p')" ]; then
    do_fatal "VPN has failed and might be exposing your real ip"
  fi
  do_pass "VPN appears to be working"
fi
