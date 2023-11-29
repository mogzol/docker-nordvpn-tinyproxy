FROM alpine:latest

RUN apk add --no-cache openvpn tinyproxy

RUN cd /etc/openvpn \
  && wget https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip \
  && unzip ovpn.zip \
  && rm ovpn.zip

WORKDIR /

COPY startup.sh startup.sh
RUN chmod +x startup.sh

CMD ./startup.sh
