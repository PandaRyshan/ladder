FROM alpine:latest

LABEL maintainer="Hu Xiaohong <xiaohong@pandas.run>"

RUN apk update \
        && apk add v2ray \
        && rm -rf /var/cache/apk/*

COPY --from=ghcr.io/ufoscout/docker-compose-wait:latest /wait /wait
COPY docker-entrypoint.sh /usr/local/bin/

#ENTRYPOINT [ "docker-entrypoint.sh" ]
ENTRYPOINT [ "v2ray", "run", "-c", "/etc/v2ray/config.json" ]

EXPOSE 7890
