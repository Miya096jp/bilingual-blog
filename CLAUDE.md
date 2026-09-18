# CLAUDE.md

このファイルは、このリポジトリで作業するClaude Code (claude.ai/code) 向けのガイドです。

## プロジェクト概要

「Dual Pascal」(dualpascal.com) は、日本語/英語のバイリンガルブログサービス。Ruby on Rails 8で作られたサーバーサイドレンダリングのWebアプリで（"blog"という名前だが静的サイトジェネレーターではない）、リポジトリのディレクトリ名 `bilingual-blog` はコードネームに過ぎず、Railsのモジュール名は `BilingualBrog` になっている（"Brog"であって"Blog"ではない点に注意）。これはタイポだが、DB名（`bilingual_brog_development`）やKamalのサービス名など複数箇所に波及しており、直すコストが見合わないため現時点では修正しない。

Dual Pascalは、読者の反応や記事の完成度を意識せず、日本語と英語の文章を自分のペースで書きためたい人向けの個人ブログサービス。ユーザーごとに独立したブログを持ち、日英いずれか、または日英セットで記事を書いて管理・公開できる。コミュニティ型のサービスではないが、第三者によるいいね・コメントは残す方針。

## 作業ルール

- ユーザーへの返答は日本語で行う。
- 1 Issue = 1 PR。Issueの範囲外のファイルは変更しない。範囲外で気づいた点があっても変更はせず、提案に留める。
- バグ修正では、まず再現する失敗テストを書いてから修正する。
- 作業の最後に `docker compose exec web bin/rails test`（必要に応じて `bin/rails test:system` も）と `docker compose exec web bin/rubocop` を実行する。
- マイグレーションは必ず可逆にする（`change` で書けない場合は `up`/`down` を明示する）。
- 本番環境（VPS）へのコマンド実行、イメージのpush、デプロイの実行は行わない。手順は `docs/deploy.md` を参照して提案するだけに留める。
- `.env`、`config/master.key`、`config/credentials.yml.enc` の中身を読まない・表示しない・コミットしない（`.claude/settings.json` でもReadツール等による読み取りを拒否している）。
- 決定事項や作業の記録は GitHub の Issue と PR に残す。
- PR の説明は敬語（です・ます調）を使わず、常体（だ・である調）で書く。

## コマンド

ローカル開発は Docker (`docker-compose.yml`) 経由。以下のコマンドは `web` コンテナが起動している前提（`docker compose up -d`）で、`docker compose exec web <command>` の形で実行する。

- **開発スタックの起動**: `docker compose up`（Postgres 16 がホスト側ポート5433、Railsが3000番ポート）
- **Rails サーバー**: `docker-compose.yml` の `web` サービスが起動時に自動で `bundle exec rails server` を実行する
- **CSSのビルド（watch）**: `docker compose exec web bin/rails "tailwindcss:watch[always]"`。`docker compose up` の `web` は `rails server` のみを起動しており、Tailwind CSSのwatchは自動起動されない。**CSSの変更を反映するには、別ターミナルでこのコマンドを起動しておく必要がある。** `[always]` を付けないと、`docker compose exec` はTTYなしのセッションになりビルドを1回実行しただけでプロセスが終了してしまう（実際に検証済み）。ファイル変更の検知自体はポーリング不要で機能する。
- **テスト**: `docker compose exec web bin/rails test` / `bin/rails test:system`（minitest、system testsはCapybara + Selenium）
- **Lint**: `docker compose exec web bin/rubocop`（rubocop-rails-omakaseベース、`.rubocop.yml` 参照）
- **セキュリティスキャン**: `docker compose exec web bin/brakeman`
- **DB**: `docker compose exec web bin/rails db:prepare` / `db:migrate` / `db:seed`

CI は未設定（`.github/` には `dependabot.yml` のみ）。JSのパッケージマネージャーによるビルドフローもない — `package.json` は devDependencyが1つあるだけでscriptsは無く、フロントエンド資産は `importmap-rails` と `tailwindcss-rails` gem経由で配信される。

## アーキテクチャ

**バイリンガルコンテンツモデル。** 記事のペアリングはファイルベースではなくデータベースの関係で表現される（言語ごとのコンテンツフォルダやfrontmatterは無い）。`Article` (`app/models/article.rb`) は `locale` カラム（`ja`/`en`）を持ち、`original_article_id` を介した自己参照（`belongs_to :original_article` / `has_one :translation`）で対訳がリンクされる。翻訳作成のフローは `Dashboard::TranslationsController#new` にあり、元記事から新しい下書きを作成しロケールを反転させる。ルーティングは `dashboard/articles/:article_id/translation` にネストされたリソースとして定義されている。この「`_ja`/`_en` のペアカラム」というパターン（専用の翻訳テーブルではなく）は他のモデルにも繰り返し現れる：`Category#locale`、`BlogSetting`（`blog_title_ja/en`、`blog_subtitle_ja/en`）、`User`（`nickname_ja/en`、`bio_ja/en`、`location_ja/en`）。

**ロケールスコープされたルーティングの分離。** 公開向けルートは `scope "/:locale", constraints: { locale: /ja|en/ }` 配下にある（例: `/ja/u/:username/articles`）が、`dashboard`（著者用CMS）と `admin` の名前空間は意図的にロケールスコープの外に置かれている — `ApplicationController#set_locale` は `/dashboard` または `/admin` で始まるパスを特別扱いし、訪問者のロケールに関わらずデフォルトロケール（`ja`）を強制する。ルートやリンクを追加する際は、dashboard/adminルートを誤ってロケールスコープしたり、逆に公開ルートのロケールスコープを外したりしないよう注意する。

RailsのUI文字列のi18n（`config/locales/ja.yml`, `config/locales/en.yml`）は、上記の`Article`/翻訳のペアリングとは別の関心事— chrome/ラベルの翻訳用であり、バイリンガル記事コンテンツ用ではない。

**ルート名前空間**（`config/routes.rb`）: 公開クライアント（ロケールスコープされた記事/検索/プロフィール/法的ページ/固定ページ）、`dashboard`（著者CMS: 記事、翻訳、カテゴリ、コメント、画像、プロフィール、ブログ設定、分析、添付ファイル）、`admin`（サイト管理: ユーザー、記事、問い合わせ）。ビューは `app/views/` 配下でこの構成をミラーしており、ERBではなくSlim (`slim-rails`) で書かれている。

**フロントエンド。** Hotwire (Turbo + Stimulus) を使用し、React/Vueなし、JSバンドラーなし — Stimulusコントローラーは `app/javascript/controllers/` にある（例: `auth_modal_controller.js`、`markdown_preview_controller.js`、`layout_switcher_controller.js`、`theme_controller.js`）。

**ストレージ。** `config/storage.yml` は開発環境向けの `local` ディスクストレージと、本番の画像/カバー画像アップロード向けのCloudflare R2（S3互換、`CLOUDFLARE_R2_*` 環境変数経由）を定義している。本番のシークレットの置き場所については「本番環境・デプロイ」セクションを参照。

**過去の開発ログ。** `docs/dev_log.md` は日本語で書かれた開発記録だが、現在は更新していない（過去の記録として残している）。今後の決定事項や作業記録は上記の通りGitHubのIssue/PRに残す。

## 本番環境・デプロイ

Dual PascalはVPS1台上でDocker Compose（`compose.prod.yaml` + `Caddyfile`）を使って稼働している。**Kamalは使用していない**（詳細は下記「既知の課題」を参照）。

サービス構成: `db`（Postgres 15）、`web`（Rails、`127.0.0.1:3000` にバインド）、`caddy`（HTTPS終端、`web:3000` へリバースプロキシ）、`worker`（Solid Queue）。本番DBはVPS上の `db` コンテナ自身（Supabase等の外部マネージドDBではない）。画像はCloudflare R2に保存される。

イメージのビルド・Docker Hub（`docmiya/bilingual-blog`）へのpushは、mainブランチへのマージ時にGitHub Actions（`.github/workflows/ci.yml` の `build` ジョブ）がCI（テスト・rubocop）成功後に自動実行し、`latest` とコミットの短縮SHAの2タグをpushする。VPSへの反映（pull → up -d）は、`build` に続く `deploy` ジョブが行う。`deploy` ジョブは `environment: production` を指定しており、GitHubのEnvironment保護ルールで承認するまで実行されない（承認しなければVPSには何も起きない）。承認後はデプロイ専用のSSH鍵でVPSに接続し、`authorized_keys` の強制コマンドとして登録された `script/vps_deploy.sh` が `.env` の `IMAGE_TAG` を書き換えたうえで `pull`/`up -d` を実行し、`docker compose ps` でサービスの起動を確認する（詳細は `docs/deploy.md`）。`compose.prod.yaml` の `web`/`worker` の `image` は `docmiya/bilingual-blog:${IMAGE_TAG:-latest}` で、`IMAGE_TAG` を指定すれば手動デプロイ時にロールバックもできる。

シークレットの置き場所: 本番はVPS上の `.env`（キー一覧は `.env.production.example`）。GitHub/Google OAuth、Resend、Umamiのフォールバック設定は `config/credentials.yml.enc`（`RAILS_MASTER_KEY` で復号）。開発は自身の `.env`（`docker-compose.yml` の `env_file`）。これらのファイルの値をコミット・出力・エージェントに読ませることはしない。

デプロイ手順、本番コンソールの起動方法、`compose.prod.yaml`/`Caddyfile` の反映方法、DBバックアップ・リストア手順は `docs/deploy.md` を参照。本番へのコマンド実行やデプロイの実行はこのリポジトリで作業するエージェントの役割ではない — 手順を提案するに留める。

## 既知の課題

- **Kamalの残骸**: `config/deploy.yml`、`.kamal/`、`bin/kamal` は `rails new`/`kamal init` 時点の未編集のひな形で、デプロイには使われていない。意図的に削除せず残している（実際のデプロイ手順は `docs/deploy.md` を参照）。
- **いいねがログイン必須になっている**: `app/controllers/likes_controller.rb` に `before_action :authenticate_user!` があり、匿名の読者はいいねできない。プロダクトの方針（第三者のいいねを残す）と食い違っているが、このIssueでは修正しない。
