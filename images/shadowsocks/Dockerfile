# ---- build stage ----
FROM alpine:edge AS builder

# 可配置版本号
ARG VERSION=1.23.5
ARG TARGETARCH

# 准备下载/解压工具
RUN apk add --no-cache curl xz

WORKDIR /tmp/ss

# 根据目标架构选择对应的 musl 预编译包并解压
RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) ARCH="x86_64-unknown-linux-musl" ;; \
      arm64) ARCH="aarch64-unknown-linux-musl" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    BASE_URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/v${VERSION}/shadowsocks-v${VERSION}.${ARCH}.tar.xz"; \
    echo "Downloading ${BASE_URL}..."; \
    curl -L -o shadowsocks.tar.xz "${BASE_URL}"; \
    tar -xf shadowsocks.tar.xz; \
    ls -lah /tmp/ss

# ---- runtime ----
FROM alpine:edge

# 运行时安装 openssl 等依赖（确保 entrypoint.sh 可以使用 openssl）
RUN apk add --no-cache ca-certificates tzdata curl openssl

# 创建目录
RUN mkdir -p /etc/shadowsocks /var/log/shadowsocks

WORKDIR /etc/shadowsocks

# 拷贝 builder 解压后的文件到运行时（包含所有二进制）
COPY --from=builder /tmp/ss/ /usr/local/bin/

# 设置可执行权限（若部分二进制不存在则忽略）
RUN chmod +x /usr/local/bin/ssserver /usr/local/bin/ssurl /usr/local/bin/sslocal /usr/local/bin/ssmanager || true

# 拷贝 entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 默认端口
EXPOSE 8388/tcp 8388/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/ssserver", "-c", "/etc/shadowsocks/config.json"]
