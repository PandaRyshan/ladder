FROM alpine:edge

LABEL maintainer="Hu Xiaohong <xiaohong@pandas.run>"

ENV VERSION="v5.30.0"
ENV ARCH="64"
ENV ZIPFILE="v2ray-linux-${ARCH}.zip"

ARG TARGETARCH
RUN case ${TARGETARCH} in \
        "amd64") ARCH="64" ;; \
        "arm64") ARCH="arm64-v8a" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac

ENV URL="https://github.com/v2fly/v2ray-core/releases/download/${VERSION}/${ZIPFILE}"

RUN apk update \
        && apk add --no-cache --quiet curl unzip \
        && curl -LO ${URL} \
        && unzip ${ZIPFILE} v2ray geoip-only-cn-private.dat config.json \
                geosite.dat geoip.dat -d . \
        && mv v2ray /usr/bin \
        && mkdir -p /usr/share/v2ray/ && mv geo*.dat /usr/share/v2ray/ \
        && mkdir -p /etc/v2ray/ && mv config.json /etc/v2ray/ \
        && apk del curl unzip \
        && rm -rf /var/cache/apk/* ${ZIPFILE}

COPY docker-entrypoint.sh /usr/bin/docker-entrypoint.sh
COPY --from=ghcr.io/ufoscout/docker-compose-wait:latest /wait /wait

ENTRYPOINT [ "docker-entrypoint.sh" ]
