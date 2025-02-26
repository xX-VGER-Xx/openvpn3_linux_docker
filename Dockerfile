# Based on information from https://github.com/OpenVPN/openvpn3-linux/issues/50
FROM alpine AS builder

RUN apk add --no-cache autoconf \
                       autoconf-archive \
                       automake \
                       g++ \
                       git \
                       glib-dev \
                       jsoncpp-dev \
                       libcap-ng-dev \
                       libnl3-dev \
                       lz4-dev \
                       make \
                       openssl-dev \
                       pkgconfig \
                       protobuf-dev \
                       py3-dbus-dev \
                       py3-jinja2 \
                       tinyxml2-dev

RUN git clone --depth 1 --single-branch https://github.com/OpenVPN/openvpn3-linux.git
RUN cd openvpn3-linux &&  \
    ./bootstrap.sh && \
    ./configure --enable-dco \
                --disable-addons-aws \
                --disable-bash-completion \
                --disable-build-test-progs \
                --disable-selinux-build \
                --localstatedir=/tmp/ && \
    make


FROM alpine

RUN apk add --no-cache curl \
                       dbus \
                       glib \
                       iptables \
                       ip6tables \
                       jsoncpp \
                       libcap-ng \
                       libnl3 \
                       libuuid \
                       lz4-dev \
                       protobuf \
                       tinyxml2 \
                       python3

COPY --from=builder /openvpn3-linux/src/ovpn3cli/openvpn3 /usr/local/bin/openvpn3

COPY --from=builder /openvpn3-linux/src/configmgr/openvpn3-service-configmgr \
                    /usr/local/libexec/openvpn3-linux/openvpn3-service-configmgr
COPY --from=builder /openvpn3-linux/src/sessionmgr/openvpn3-service-sessionmgr \
                    /usr/local/libexec/openvpn3-linux/openvpn3-service-sessionmgr
COPY --from=builder /openvpn3-linux/src/log/openvpn3-service-logger \
                    /usr/local/libexec/openvpn3-linux/openvpn3-service-logger
COPY --from=builder /openvpn3-linux/src/client/openvpn3-service-client \
                    /usr/local/libexec/openvpn3-linux/openvpn3-service-client
COPY --from=builder /openvpn3-linux/src/client/openvpn3-service-backendstart \
                    /usr/local/libexec/openvpn3-linux/openvpn3-service-backendstart
COPY --from=builder /openvpn3-linux/src/netcfg/openvpn3-service-netcfg \
                    /usr/local/libexec/openvpn3-linux/openvpn3-service-netcfg
COPY --from=builder /openvpn3-linux/src/python/openvpn3-autoload \
                     /usr/local/libexec/openvpn3-linux/openvpn3-autoload                  

COPY --from=builder /openvpn3-linux/src/service-autostart/*.service /usr/share/dbus-1/system-services/
COPY --from=builder /openvpn3-linux/src/policy/*.conf /usr/share/dbus-1/system.d/

RUN sed -i 's/--log-level 4/--log-level 6/' /usr/share/dbus-1/system-services/net.openvpn.v3.log.service
RUN sed -i 's|--syslog|--log-file /proc/1/fd/0|' /usr/share/dbus-1/system-services/net.openvpn.v3.log.service
RUN ln -sf python3 /usr/bin/python

COPY . /

RUN addgroup openvpn && \
    adduser -D openvpn -G openvpn
RUN mkdir -p /tmp/lib/openvpn3/configs

HEALTHCHECK --interval=60s \
            --timeout=15s \
            --start-period=120s \
            CMD if [ -n "$VPN_EXTERNAL_IP" ]; then \
                  test $(curl -LSs https://api.ipify.org) = $VPN_EXTERNAL_IP; \
                else \
                  curl -LSs https://api.ipify.org; \
                fi || exit 1
ENTRYPOINT ["/entrypoint.sh"]
