# nordvpn-tinyproxy

A simple Docker image which connects to NordVPN using OpenVPN, and hosts an HTTP proxy with tinyproxy to allow using the VPN connection.

## Usage:

Start this image with a command like the one below. Once started, you should be able to connect to the HTTP proxy on port 8888.

```
docker run \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  --dns 1.1.1.1 \
  --restart unless-stopped  \
  -p 8888:8888 \
  -e "USERNAME=<your nord username>" \
  -e "PASSWORD=<your nord password>" \
  -e "SERVER=<nordvpn server>" \
  mogzol/nordvpn-tinyproxy
```

Note that the `--cap-add`, and `--device` options are required for the image to work, and the `--dns` option is required to allow the container to do DNS queries after the VPN connection is established (although you can specify whatever DNS server you want, doesn't need to be `1.1.1.1`).

The `USERNAME` and `PASSWORD` environment variables should be your NordVPN service credentials, not your regular username and password. See here for how to get those: https://support.nordvpn.com/General-info/1653315162/Changes-to-the-login-process-on-third-party-apps-and-routers.htm

The `SERVER` environment variable should be whatever NordVPN server you want to connect to (for example `us5086.nordvpn.com`). You can use this page to find one: https://nordvpn.com/servers/tools/

If the VPN connection ever dies, the container will stop, so it is recommended to use the `--restart` option to have it automatically restart.

## Environment Variables

| Variable         | Description                                                                                        |
| ---------------- | -------------------------------------------------------------------------------------------------- |
| `USERNAME`       | Your NordVPN service credentials username. **(required)**                                          |
| `PASSWORD`       | Your NordVPN service credentials password. **(required)**                                          |
| `SERVER`         | The NordVPN server to connect to. **(required)**                                                   |
| `PORT`           | The port within the container to run the HTTP proxy on. (optional, default `8888`)                 |
| `PROXY_USERNAME` | The username to use for the HTTP proxy. (optional, if unset the proxy will not use authentication) |
| `PROXY_PASSWORD` | The password to use for the HTTP proxy. (optional, if unset the proxy will not use authentication) |
