FROM alpine:latest

LABEL maintainer="Hu Xiaohong <xiaohong@pandas.run>"

ENV VERSION="v5.18.0"
ENV ZIPFILE="v2ray-linux-64.zip"
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

COPY --from=ghcr.io/ufoscout/docker-compose-wait:latest /wait /wait

ENTRYPOINT [ "v2ray", "run", "-c", "/etc/v2ray/config.json" ]

EXPOSE 8001
