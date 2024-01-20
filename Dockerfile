FROM alpine:latest

LABEL maintainer="Hu Xiaohong <xiaohong@pandas.run>"

RUN apk update \
        && apk add v2ray \
        && rm -rf /var/cache/apk/*

ENTRYPOINT ["v2ray", "run", "-c", "/etc/v2ray/config.json"]
