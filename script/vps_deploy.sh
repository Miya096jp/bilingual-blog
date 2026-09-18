#!/usr/bin/env bash
# VPS上でauthorized_keysの強制コマンド(command=)として実行する想定のスクリプト。
# GitHub ActionsからのSSH接続時に渡されるコマンド文字列($SSH_ORIGINAL_COMMAND)を
# デプロイするイメージの短縮SHAとして受け取り、.envのIMAGE_TAGを書き換えたうえで
# pull・upを実行する。詳細はdocs/deploy.mdを参照。
set -euo pipefail

cd "$(dirname "$0")/.."

COMPOSE_FILE="compose.prod.yaml"
ENV_FILE=".env"
SERVICES="db web caddy worker"

IMAGE_TAG="${SSH_ORIGINAL_COMMAND:-}"

if [[ ! "$IMAGE_TAG" =~ ^[0-9a-f]{7,40}$ ]]; then
  echo "invalid IMAGE_TAG: '${IMAGE_TAG}'" >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "${ENV_FILE} not found" >&2
  exit 1
fi

backup_file="${ENV_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp -p "$ENV_FILE" "$backup_file"

tmp_file="$(mktemp "${ENV_FILE}.tmp.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT

if grep -q '^IMAGE_TAG=' "$ENV_FILE"; then
  sed "s/^IMAGE_TAG=.*/IMAGE_TAG=${IMAGE_TAG}/" "$ENV_FILE" > "$tmp_file"
else
  cp "$ENV_FILE" "$tmp_file"
  printf 'IMAGE_TAG=%s\n' "$IMAGE_TAG" >> "$tmp_file"
fi

chmod 600 "$tmp_file"
mv "$tmp_file" "$ENV_FILE"

docker compose -f "$COMPOSE_FILE" pull
docker compose -f "$COMPOSE_FILE" up -d

echo "waiting for containers to settle..."
sleep 5

failed=0
for svc in $SERVICES; do
  state="$(docker compose -f "$COMPOSE_FILE" ps --format '{{.State}}' "$svc" 2>/dev/null || true)"
  if [[ "$state" != "running" ]]; then
    echo "service '${svc}' is not running (state: '${state:-unknown}')" >&2
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo "deploy failed: some services are not running (backup: ${backup_file})" >&2
  exit 1
fi

echo "deploy succeeded: IMAGE_TAG=${IMAGE_TAG}"
