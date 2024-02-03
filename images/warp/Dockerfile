FROM ubuntu:latest
LABEL maintainer="Hu Xiaohong <xiaohong@pandas.run>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -x \
  && apt update && apt install -y cron socat curl gpg lsb-release \
  && curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg \
    | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
  && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/cloudflare-client.list \
  && apt update && apt install -y cloudflare-warp \
  && apt purge --auto-remove -y curl lsb-release \
  && apt clean && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT [ "docker-entrypoint.sh" ]

EXPOSE 40001
