FROM alpine:latest

RUN apk add --no-cache openvpn tinyproxy iputils bind-tools curl bash jq && \
    cd /etc/openvpn && \
    curl --location --silent --fail https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip -o /tmp/ovpn.zip && \
    unzip ovpn.zip && \
    rm /tmp/ovpn.zip

WORKDIR /

COPY scripts/ /usr/local/bin/

ENTRYPOINT ["/usr/bin/sh", "-c", "/usr/local/bin/healthcheck.sh -s; /usr/local/bin/startup.sh ${@}" ]
