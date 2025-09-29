#!/bin/sh
set -eu

CONFIG_FILE="/etc/shadowsocks/config.json"
DEFAULT_METHOD="2022-blake3-chacha20-poly1305"

# env
SERVER_PORT="${SERVER_PORT:-8388}"
METHOD="${METHOD:-$DEFAULT_METHOD}"
USER_PASSWORD="${PASSWORD:-}"

# determine required key bytes for 2022 methods
_required_key_bytes() {
  m="$1"
  case "$m" in
    *aes-128*) echo 16 ;;   # AES-128 -> 16 bytes
    *aes-256*) echo 32 ;;   # AES-256 -> 32 bytes
    *chacha* ) echo 32 ;;   # chacha variants -> 32 bytes
    * ) echo 32 ;;
  esac
}

# check if a string decodes to exactly want_bytes when base64-decoded
_is_base64_of_len_bytes() {
  s="$1"; want_bytes="$2"
  if command -v openssl >/dev/null 2>&1; then
    # -A avoid newline; -d decode; wc -c count bytes
    decoded_len=$(printf "%s" "$s" | openssl base64 -d 2>/dev/null | wc -c 2>/dev/null || true)
    [ -n "$decoded_len" ] || return 1
    [ "$decoded_len" -eq "$want_bytes" ]
    return $?
  else
    return 1
  fi
}

# derive binary (sha256), truncate to want_bytes, output base64 (no newline)
_derive_base64_truncate() {
  pass="$1"; want_bytes="$2"
  if command -v openssl >/dev/null 2>&1; then
    printf "%s" "$pass" | openssl dgst -sha256 -binary | dd bs=1 count="$want_bytes" 2>/dev/null | openssl base64 -A
  else
    # fallback: use /dev/urandom derived - but openssl expected in runtime
    dd if=/dev/urandom bs="$want_bytes" count=1 2>/dev/null | openssl base64 -A
  fi
}

# generate random raw key of want_bytes and output base64
_generate_random_base64() {
  want_bytes="$1"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 "$want_bytes"
  else
    dd if=/dev/urandom bs="$want_bytes" count=1 2>/dev/null | openssl base64 -A
  fi
}

prepare_password() {
  method="$1"
  userpw="$2"

  if printf "%s" "$method" | grep -q "^2022-" >/dev/null 2>&1; then
    want_bytes=$(_required_key_bytes "$method")

    if [ -n "$userpw" ]; then
      # If user provided a base64 that decodes to required bytes -> accept as-is
      if _is_base64_of_len_bytes "$userpw" "$want_bytes"; then
        printf "%s" "$userpw"
        return 0
      fi

      # otherwise derive a reproducible key from passphrase and output base64
      echo "[entrypoint] provided PASSWORD is not a base64 raw-key of ${want_bytes} bytes; deriving ${want_bytes}-byte key from passphrase (sha256 -> truncate)..." >&2
      _derive_base64_truncate "$userpw" "$want_bytes"
      return 0
    else
      # no password provided -> generate random raw key (base64)
      echo "[entrypoint] no PASSWORD provided; generating random ${want_bytes}-byte raw key (base64)..." >&2
      _generate_random_base64 "$want_bytes"
      return 0
    fi
  else
    # non-2022: accept provided password, or generate short base64
    if [ -n "$userpw" ]; then
      printf "%s" "$userpw"
    else
      if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 16
      else
        dd if=/dev/urandom bs=16 count=1 2>/dev/null | openssl base64 -A
      fi
    fi
    return 0
  fi
}

# If config exists, use unchanged
if [ -s "$CONFIG_FILE" ]; then
  echo "[entrypoint] using existing config: $CONFIG_FILE" >&2
  exec "$@"
fi

PASSWORD_FINAL="$(prepare_password "$METHOD" "$USER_PASSWORD")"

echo "[entrypoint] generating $CONFIG_FILE (method=${METHOD})" >&2
cat >"$CONFIG_FILE" <<EOF
{
  "servers": [
    {
      "server": "0.0.0.0",
      "server_port": ${SERVER_PORT},
      "password": "${PASSWORD_FINAL}",
      "method": "${METHOD}",
      "mode": "tcp_and_udp",
      "fast_open": false
    }
  ]
}
EOF

echo "[entrypoint] generated $CONFIG_FILE (password is base64 for 2022 methods)." >&2
exec "$@"

