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

## 自動デプロイ（GitHub Actions、承認付き）

`build` ジョブの成功後、`ci.yml` の `deploy` ジョブがVPSへのデプロイを行う。`environment: production` を指定しており、GitHubのEnvironment保護ルールで承認者が承認するまでジョブは停止したまま実行されない。承認しなければVPSには何も起きない。

### 流れ

1. mainへのマージ → `test`/`lint` → `build`（イメージのビルド・push）が成功する
2. `deploy` ジョブが承認待ちで停止する（GitHubのActions画面から承認する）
3. 承認すると、`deploy` ジョブがデプロイ専用のSSH鍵でVPSに接続し、そのコミットの短縮SHAをコマンド文字列として渡す
4. VPS側では `authorized_keys` の強制コマンド（`command=`）として登録された `script/vps_deploy.sh` が実行され、渡された短縮SHAを検証したうえで `.env` の `IMAGE_TAG` を書き換え、`docker compose -f compose.prod.yaml pull && up -d` を実行する。実行後、`docker compose ps` で各サービスが起動しているかを確認し、異常があれば非ゼロで終了する（`script/vps_deploy.sh` 参照）
5. `deploy` ジョブはさらに `https://dualpascal.com/up`（Railsのヘルスチェックエンドポイント）にHTTPSでアクセスし、応答が無ければジョブを失敗させる。ただし `/up` は古いバージョンでも200を返すため、デプロイの成否そのものは主に手順4の `docker compose ps` チェックで判断しており、この手順5は疎通確認の位置づけ

デプロイに失敗しても自動では切り戻さない。手動ロールバック手順は下記を参照する。

### 必要なSecrets / Variables

- Secrets（リポジトリレベルに登録済み。`environment: production` を指定したジョブからも参照できる）
  - `VPS_SSH_KEY`: デプロイ専用のSSH秘密鍵（ed25519、普段使いの鍵とは別に新規作成したもの）
  - `VPS_HOST`: VPSのホスト名/IP
  - `VPS_USER`: SSH接続ユーザー名
- Variables
  - `VPS_KNOWN_HOSTS`: `ssh-keyscan -H <VPS_HOST>` の出力をそのまま保存したもの。ワークフロー内で `~/.ssh/known_hosts` に書き込み、`StrictHostKeyChecking=yes` のままホスト鍵を検証する（`StrictHostKeyChecking=no` は使わない）

ホスト名・ユーザー名はこのリポジトリが公開でActionsのログも公開されるため、Variablesではなく非公開のSecretsとして扱っている。ホストの公開鍵情報（`VPS_KNOWN_HOSTS`）自体は機密ではないためVariablesで問題ない。

### VPS側の設定（この手順はユーザーが実施する。エージェントはVPSへのコマンド実行を行わない）

1. デプロイ専用のSSH鍵（ed25519）を新規に作成し、秘密鍵を `VPS_SSH_KEY` に登録する
2. `script/vps_deploy.sh` をVPSの `/home/ubuntu/bilingual-blog/script/vps_deploy.sh` に配置し、実行権限を付与する
3. VPSの `authorized_keys` に、この鍵専用のエントリを強制コマンド付きで追加する:
   ```
   command="/home/ubuntu/bilingual-blog/script/vps_deploy.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty,no-user-rc ssh-ed25519 AAAA...（デプロイ専用鍵の公開鍵）
   ```
   これにより、この鍵で接続してもポート転送やシェルの取得はできず、常に `script/vps_deploy.sh` だけが実行される（GitHub Actionsから渡したコマンド文字列は `$SSH_ORIGINAL_COMMAND` としてスクリプトに渡る）

## 通常のデプロイ手順（自動デプロイが使えない場合の手動手順）

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

`compose.prod.yaml` の `web`/`worker` の `image` は `docmiya/bilingual-blog:${IMAGE_TAG:-latest}` で、`IMAGE_TAG` 未設定時は `latest` が使われる。自動デプロイ（`script/vps_deploy.sh`）はデプロイのたびにVPSの `.env` の `IMAGE_TAG` をそのコミットの短縮SHAに書き換えるため、通常運用では `.env` に常に直近デプロイのSHAが入っている状態になる（`latest` が使われるのは、自動デプロイを一度も行っていない初期状態など `.env` に `IMAGE_TAG` が無い場合のみ）。

以前のバージョンに戻す場合は、VPSの `~/bilingual-blog` で戻したいコミットの短縮SHAタグを指定して起動する:

```bash
IMAGE_TAG=<短縮SHA> docker compose -f compose.prod.yaml up -d
```

このコマンドはコマンドラインで一時的に指定するだけで、`.env` の `IMAGE_TAG` は書き換わらない。そのため、その後に自動デプロイやGitHub Actions経由でない `up -d` が実行されると、`.env` に書かれたSHA（＝ロールバック前のバージョン）に戻ってしまう点に注意する。`.env` 自体を書き換えて固定したい場合は、`script/vps_deploy.sh` と同様にバックアップを取ってから `IMAGE_TAG` 行を書き換える。

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
