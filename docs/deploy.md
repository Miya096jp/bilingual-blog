# デプロイ手順

本番はVPS上でDocker Composeを使って稼働している。**Kamalは使用していない**（`config/deploy.yml`、`.kamal/` は未使用の残骸。詳細はCLAUDE.mdの「既知の課題」を参照）。

## 構成

- VPS上の配置先: `~/bilingual-blog`（gitリポジトリではなく、ファイルを直接配置している）
- サービス（`compose.prod.yaml`）:
  - `db`: Postgres 15
  - `web`: Railsアプリ本体、`127.0.0.1:3000` にバインド
  - `caddy`: HTTPS終端、`web:3000` へリバースプロキシ（`Caddyfile` 参照）
  - `worker`: Solid Queue（`bin/rails solid_queue:start`）
- 本番DBはVPS上の `db` コンテナ自身（Supabase等の外部マネージドDBではない）
- 画像はCloudflare R2に保存している

## 通常のデプロイ手順

1. ローカル（Mac）でmainブランチを最新にする
2. イメージをビルドしてpushする:
   ```bash
   docker buildx build --platform linux/amd64 -t docmiya/bilingual-blog:latest --push .
   ```
3. VPSの `~/bilingual-blog` ディレクトリで最新イメージを取得して再起動する:
   ```bash
   docker compose -f compose.prod.yaml pull
   docker compose -f compose.prod.yaml up -d
   ```
4. 起動確認:
   ```bash
   docker compose -f compose.prod.yaml ps
   docker compose -f compose.prod.yaml logs -f web
   ```

## `compose.prod.yaml` / `Caddyfile` を変更した場合

このリポジトリの `compose.prod.yaml` と `Caddyfile` が正。変更した場合は、VPS上のファイルへ `scp` 等で反映する（VPS側はgitリポジトリではないため `git pull` は使えない）。

- Caddyfileのみ変更した場合は、Caddyコンテナだけ再起動すればよい:
  ```bash
  docker compose -f compose.prod.yaml restart caddy
  ```
- `compose.prod.yaml` 自体を変更した場合は、上記の通常デプロイ手順（pull → up -d）を実行する。

## 本番Railsコンソール

```bash
docker compose -f compose.prod.yaml run --rm web bundle exec rails c
```

## シークレット

- 本番: VPSの `.env`（キー一覧は `.env.production.example` を参照）
- OAuth（GitHub/Google）・Resend・Umamiのフォールバック設定: `config/credentials.yml.enc`（`RAILS_MASTER_KEY` で復号）
- 開発: ローカルの `.env`（`docker-compose.yml` の `env_file` から読み込み）
- これらのファイルの中身はコミット・出力せず、エージェントにも読ませない（`.claude/settings.json` 参照）

## DBバックアップ・リストア

自動バックアップは行っていない。マイグレーションを含むデプロイなど、データに影響しうる作業の前に手動でバックアップを取る（方針の詳細はIssue #32を参照）。

### バックアップ（VPSの `~/bilingual-blog` で実行）

```bash
docker compose -f compose.prod.yaml exec -T db \
  sh -c 'pg_dump -U "$POSTGRES_USER" -Fc "$POSTGRES_DB"' > backup_$(date +%Y%m%d).dump
ls -lh backup_*.dump   # サイズが0でないことを確認
```

### 手元（Mac）へのコピー（任意）

```bash
scp ubuntu@<VPSのIP>:~/bilingual-blog/backup_YYYYMMDD.dump ~/Backups/
```

### 復元（VPSの `~/bilingual-blog` で実行）

```bash
# アプリを止めてから復元する
docker compose -f compose.prod.yaml stop web worker
docker compose -f compose.prod.yaml exec -T db \
  sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists' < backup_YYYYMMDD.dump
docker compose -f compose.prod.yaml start web worker
```

### 注意

- `-T` を付けないと擬似端末が使われ、ダンプが壊れることがある
- バックアップファイルはリポジトリに入れない
- 復元手順は、実際に一度試すまでは未確認の扱いとする
