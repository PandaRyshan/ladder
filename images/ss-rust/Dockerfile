# ---- build stage ----
FROM alpine:3.19 AS builder

# 可配置版本号
ARG VERSION=1.23.5
ARG BASE_URL=https://github.com/shadowsocks/shadowsocks-rust/releases/download/v${VERSION}/shadowsocks-v${VERSION}.x86_64-unknown-linux-musl.tar.xz

# 准备下载/解压工具
RUN apk add --no-cache curl xz

WORKDIR /tmp/ss

# 下载官方 musl 预编译二进制并解压
RUN echo "Downloading shadowsocks v${VERSION}..." && \
    curl -L -o shadowsocks.tar.xz "${BASE_URL}" && \
    tar -xf shadowsocks.tar.xz && \
    ls -lah /tmp/ss

# ---- runtime ----
FROM alpine:3.19

# 运行时安装 openssl 等依赖（确保 entrypoint.sh 可以使用 openssl）
RUN apk add --no-cache ca-certificates tzdata curl openssl

# 创建目录
RUN mkdir -p /etc/shadowsocks /var/log/shadowsocks

WORKDIR /etc/shadowsocks

# 拷贝二进制文件（来自 builder 解压后的文件）
COPY --from=builder /tmp/ss/ssserver /usr/local/bin/ssserver
COPY --from=builder /tmp/ss/ssurl /usr/local/bin/ssurl
COPY --from=builder /tmp/ss/sslocal /usr/local/bin/sslocal
COPY --from=builder /tmp/ss/ssmanager /usr/local/bin/ssmanager
COPY --from=builder /tmp/ss/ssservice /usr/local/bin/ssservice

RUN chmod +x /usr/local/bin/ssserver /usr/local/bin/ssurl /usr/local/bin/sslocal /usr/local/bin/ssmanager /usr/local/bin/ssservice

# 拷贝 entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 默认端口
EXPOSE 8388/tcp 8388/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/ssserver", "-c", "/etc/shadowsocks/config.json"]
