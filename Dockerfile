# Build Flood UI seperately to keep image size small
FROM node:latest AS FloodUIBuilder
WORKDIR /tmp/flood

RUN echo "Build Flood UI" \
    && wget -qO- https://github.com/johman10/flood-for-transmission/archive/master.tar.gz | tar xz -C . --strip=1 \
    && npm ci \
    && npm run build

FROM gcr.io/prime-burner-274908/alpine:latest
COPY /etc/cont-init.d/ /etc/cont-init.d/
VOLUME /data
VOLUME /config

RUN echo "@community http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
    && apk --no-cache add ip6tables ufw@community openvpn shadow transmission-daemon transmission-cli \
        openrc jq tzdata tinyproxy tinyproxy-openrc openssh unrar git \
    && mkdir -p /opt/transmission-ui \
    && echo "Install Flood for Transmission" \
    && wget -qO- https://github.com/johman10/flood-for-transmission/releases/download/latest/flood-for-transmission.tar.gz | tar xz -C /opt/transmission-ui \
    && echo "Install Combustion" \
    && wget -qO- https://github.com/Secretmapper/combustion/archive/release.tar.gz | tar xz -C /opt/transmission-ui \
    && echo "Install kettu" \
    && wget -qO- https://github.com/endor/kettu/archive/master.tar.gz | tar xz -C /opt/transmission-ui \
    && mv /opt/transmission-ui/kettu-master /opt/transmission-ui/kettu \
    && echo "Install Transmission-Web-Control" \
    && mkdir /opt/transmission-ui/transmission-web-control \
    && curl -sL $(curl -s https://api.github.com/repos/ronggang/transmission-web-control/releases/latest | jq --raw-output '.tarball_url') | tar -C /opt/transmission-ui/transmission-web-control/ --strip-components=2 -xz \
    && ln -s /usr/share/transmission/web/style /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/images /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/javascript /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/index.html /opt/transmission-ui/transmission-web-control/index.original.html \
    && rm -rf /tmp/* /var/tmp/* \
    && groupmod -g 1000 users \
    && useradd -u 911 -U -d /config -s /bin/false abc \
    && usermod -G users abc

# Bring over flood UI from previous build stage
COPY --from=FloodUIBuilder /tmp/flood/public /opt/transmission-ui/flood

RUN chmod +x /etc/cont-init.d/run

# Add configuration and scripts
ADD openvpn/ /etc/openvpn/
ADD transmission/ /etc/transmission/
ADD tinyproxy /opt/tinyproxy/
ADD scripts /etc/scripts/

ENV OPENVPN_USERNAME=**None** \
    OPENVPN_PASSWORD=**None** \
    OPENVPN_PROVIDER=**None** \
    GLOBAL_APPLY_PERMISSIONS=true \
    TRANSMISSION_HOME=/data/transmission-home \
    TRANSMISSION_RPC_PORT=9091 \
    TRANSMISSION_DOWNLOAD_DIR=/data/completed \
    TRANSMISSION_INCOMPLETE_DIR=/data/incomplete \
    TRANSMISSION_WATCH_DIR=/data/watch \
    CREATE_TUN_DEVICE=true \
    ENABLE_UFW=false \
    UFW_ALLOW_GW_NET=false \
    UFW_EXTRA_PORTS= \
    UFW_DISABLE_IPTABLES_REJECT=false \
    PUID= \
    PGID= \
    DROP_DEFAULT_ROUTE= \
    WEBPROXY_ENABLED=false \
    WEBPROXY_PORT=8888 \
    WEBPROXY_USERNAME= \
    WEBPROXY_PASSWORD= \
    LOG_TO_STDOUT=false \
    HEALTH_CHECK_HOST=google.com

HEALTHCHECK --interval=1m CMD /etc/scripts/healthcheck.sh

# Expose port and run
EXPOSE 9091
CMD ["/etc/openvpn/start.sh"]
