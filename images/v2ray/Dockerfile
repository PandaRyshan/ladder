FROM alpine:latest

LABEL maintainer="Hu Xiaohong <xiaohong@pandas.run>"

RUN apk update \
        && apk add v2ray socat \
        && rm -rf /var/cache/apk/*

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT [ "docker-entrypoint.sh" ]

EXPOSE 7890
