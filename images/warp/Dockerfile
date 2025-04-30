FROM debian:bookworm-slim
LABEL maintainer="Hu Xiaohong <xiaohong@pandas.run>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETARCH

RUN set -x \
  && apt-get update && apt-get install -y \
     cron socat curl gpg lsb-release \
  && curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg \
    | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/cloudflare-client.list \
  && apt-get update && apt-get install -y cloudflare-warp \
  && apt-get purge --auto-remove -y curl lsb-release \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT [ "bash", "/usr/local/bin/docker-entrypoint.sh" ]

EXPOSE 40001
