# デプロイ手順

本番はVPS上でDocker Composeを使って稼働している。**Kamalは使用していない**（`config/deploy.yml`、`.kamal/` は未使用の残骸。詳細はCLAUDE.mdの「既知の課題」を参照）。

**注意**: `-f compose.prod.yaml` を付けるコマンドはVPS上でのみ実行するものである。`compose.prod.yaml` はこのリポジトリにも存在するため、手元（Mac）の作業ディレクトリで誤って実行しないよう注意する。

## 構成

- VPS上の配置先: `~/bilingual-blog`（gitリポジトリではなく、ファイルを直接配置している）
- サービス（`compose.prod.yaml`）:
  - `db`: Postgres 15
  - `web`: Railsアプリ本体、`127.0.0.1:3000` にバインド
  - `caddy`: HTTPS終端、`web:3000` へリバースプロキシ（`Caddyfile` 参照）
  - `worker`: Solid Queue（`bin/rails solid_queue:start`）
- 本番DBはVPS上の `db` コンテナ自身（Supabase等の外部マネージドDBではない）
- 画像はCloudflare R2に保存している
- `web` と `worker` は同じイメージ・`entrypoint.sh` を使うが、`RUN_DB_MIGRATE` 環境変数で `web` のみが `db:create`/`db:migrate` を実行する（`worker` は `RUN_DB_MIGRATE=false` でDB接続待ちのみ行う）。`db:seed` は `RAILS_ENV=development` のときのみ実行され、本番では実行されない
- 各サービスに `logging`（`json-file`、`max-size: 10m`、`max-file: 3`）を設定し、ログの無制限な増加を防いでいる

## イメージのビルド・push

mainブランチへのマージ時、GitHub Actions（`.github/workflows/ci.yml` の `build` ジョブ）がCI（テスト・rubocop）成功後に自動でイメージをビルドし、Docker Hub（`docmiya/bilingual-blog`）へ `latest` と コミットの短縮SHA（例 `a1b2c3d`）の2つのタグでpushする。手元（Mac）での手動ビルドは通常不要になったが、Actionsが使えない場合など必要になったときのために手順を残す:

```bash
docker buildx build --platform linux/amd64 -t docmiya/bilingual-blog:latest --push .
```

## 通常のデプロイ手順

1. mainへのマージ後、GitHub Actionsのビルドが成功したことを確認する
2. VPSの `~/bilingual-blog` ディレクトリで最新イメージを取得して再起動する:
   ```bash
   docker compose -f compose.prod.yaml pull
   docker compose -f compose.prod.yaml up -d
   ```
3. 起動確認:
   ```bash
   docker compose -f compose.prod.yaml ps
   docker compose -f compose.prod.yaml logs -f web
   ```

## ロールバック手順

`compose.prod.yaml` の `web`/`worker` の `image` は `docmiya/bilingual-blog:${IMAGE_TAG:-latest}` で、`IMAGE_TAG` 未設定時は `latest` が使われる。以前のバージョンに戻す場合は、戻したいコミットの短縮SHAタグを指定して起動する:

```bash
IMAGE_TAG=<短縮SHA> docker compose -f compose.prod.yaml up -d
```

VPSの `.env` に `IMAGE_TAG` を書いて固定することもできるが、その場合は次回の `latest` への追従が止まる（ロールバックしたままになる）。ロールバック後に `latest` へ戻すときは、VPSの `.env` から `IMAGE_TAG` を削除するか空にしてから、通常のデプロイ手順（pull → up -d）を実行する。通常運用では `.env` に `IMAGE_TAG` を書かず、コマンドラインでの一時指定にとどめることを推奨する。

## `compose.prod.yaml` / `Caddyfile` を変更した場合

このリポジトリの `compose.prod.yaml` と `Caddyfile` が正。変更した場合は、VPS上のファイルへ `scp` 等で反映する（VPS側はgitリポジトリではないため `git pull` は使えない）。

- Caddyfileのみ変更した場合は、Caddyコンテナだけ再起動すればよい:
  ```bash
  docker compose -f compose.prod.yaml restart caddy
  ```
- `compose.prod.yaml` 自体を変更した場合は、上記の通常デプロイ手順（pull → up -d）を実行する。`up -d` は設定内容のハッシュを比較しており、`db`/`caddy` のようにイメージが変わらないサービスでも、`logging` など設定自体が変わっていればコンテナを再作成する。念のため反映を確認する場合は以下を実行する:
  ```bash
  docker inspect --format '{{.HostConfig.LogConfig}}' bilingual-blog-db-1 bilingual-blog-caddy-1
  ```
  反映されていなければ、対象サービスだけ強制的に再作成する:
  ```bash
  docker compose -f compose.prod.yaml up -d --force-recreate db caddy
  ```

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
