# Dual Pascal

## 概要
日本語と英語の文章を、自分のペースで書きためるための個人ブログサービスです。
ユーザーごとに独立したブログを持ち、日本語・英語のどちらか、または日英ペアで記事を書いて管理・公開できます。

リポジトリ名`bilingual-blog`は開発時のコードネームです。


## 開発の経緯
もともとはFJORD BOOT CAMPでWeb開発を学習しているときに、スクールの課題とは別に自学自習の目的で作り始めたアプリです。設計・プロトタイピングを自分で行い、AIチャットに相談しながらコードを1つずつ理解・検証して組み上げました。初期は学習目的だったため、コミットの粒度が粗くなっています。
デプロイ後、半年以上の時間を空けてから、Claude Codeを導入し、UIの改善、セキュリティ対策、細かなバグ対応などを行いました。それ以降は、1Issue = 1PRで開発、保守・運用を行っています。

詳しい経緯は[リリースブログ](https://dualpascal.com/ja/u/ymiyawaki/articles)に書いています。


## 主な機能

- 日本語と英語の好きな方でまず記事を書き、その記事に対して翻訳記事を対訳として紐づけて管理・公開できます
- 公開ページは`/ja`, `/en`でURLを分け、ヘッダーの言語選択ボタンでそれぞれの言語のページに切り替えることができます
- 記事以外にも、カテゴリ、ブログタイトル、ニックネーム・自己紹介などを日英でそれぞれ設定可能です
- 記事のエディターはリアルタイムプレビューとシンタックスハイライトを備えており、翻訳記事を作成する場合は、原文を表示することができます
- 5種類のカラーテーマ、3種類のレイアウト、サムネイル表示タイプの切り替えができます
- Umami(OSSのアクセス解析ダッシュボード)で、各ユーザーが自分のブログのアクセス解析をそれぞれのダッシュボードで表示できます
- メールアドレスとパスワード、GitHub/Googleでのソーシャルログインに対応しています
- コメント、いいね、問い合わせフォーム

## 画面サンプル

### クライアント画面
- サービストップ: https://dualpascal.com
- ブログ閲覧: https://dualpascal.com/ja/u/ymiyawaki/articles
  
<img width="950" height="605" alt="スクリーンショット 2026-11-09 16 52 08" src="https://github.com/user-attachments/assets/fb1b725d-8376-412c-9150-fd33a9d3e954" />


### ダッシュボードトップ

<img width="930" height="638" alt="スクリーンショット 2026-11-09 16 59 27" src="https://github.com/user-attachments/assets/8ca50199-7806-464a-9986-72d2623c32c6" />

### エディター

<img width="931" height="762" alt="スクリーンショット 2026-11-09 17 01 22" src="https://github.com/user-attachments/assets/559c35d0-875b-4403-a3ac-a76fa9f37ad5" />

### アナリティクス

<img width="914" height="871" alt="スクリーンショット 2026-11-09 17 02 32" src="https://github.com/user-attachments/assets/e9d7aa03-72b2-4586-b70c-59e1893ee75b" />



## 技術スタック
- **言語・フレームワーク**：Ruby 3.3.4 / Ruby on Rails 8.1.4
- **フロントエンド**：Hotwire（Turbo / Stimulus）、Tailwind CSS 4、Slim、importmap（JSバンドラーなし）
- **データベース**：PostgreSQL
- **認証**：Devise、OmniAuth（GitHub / Google）
- **Markdown**：kramdown（GFM）、Rouge
- **バックグラウンドジョブ**：Solid Queue（定期ジョブ含む）
- **ファイルストレージ**：Active Storage + Cloudflare R2
- **メール送信**：Resend
- **セキュリティ**：Rack::Attack、Brakeman
- **テスト・静的解析**：Minitest、RuboCop（rubocop-rails-omakase）
- **インフラ**：さくらのVPS、Docker Compose、Caddy、Docker Hub
- **CI/CD**：GitHub Actions
- **アクセス解析**：Umami（Vercel + Supabase）
- **開発支援**：Claude Code

## ローカル環境での起動

### 起動方法

```bash
git clone https://github.com/Miya096jp/bilingual-blog.git
cd bilingual-blog
touch .env
docker compose up -d
```
http://localhost:3000 で起動します。
seed で作られるアカウント（例: `admin@example.com` / `password`）でログインできます。開発環境ではメールは送信されず、/letter_opener で確認します。

CSS を変更する場合は、別のターミナルで次を実行します。

```bash
docker compose exec web bin/rails "tailwindcss:watch[always]"
```

### テスト・静的解析

```bash
docker compose exec web bin/rails test
docker compose exec web bin/rubocop
docker compose exec web bundle exec brakeman --no-pager
```

### APIキーについて
外部サービスを使う機能はそれぞれAPIキーが必要です。

 | 機能 | 必要なもの |
 | --- | --- | 
 | 画像のアップロード | Cloudflare R2 のバケットとアクセスキー |
 | GitHub / Google でのログイン | 各サービスの OAuth アプリと Rails credentials |


#### アクセス解析（Umami）について
本番では、OSSのアクセス解析ツールUmamiをVercelにホストして運用しています（データベースはSupabase）。
ローカルで使う場合は、Umamiを別途ホストし、`.env` に次の値を設定してください。

- `UMAMI_API_CLIENT_HOST`：UmamiのURL
- `UMAMI_API_CLIENT_USERNAME` / `UMAMI_API_CLIENT_PASSWORD`：Umamiのアカウント


## 今後の改善について
このアプリは学習の初期段階で開発に着手したことから、改善すべき点が多く存在します。セキュリティ問題については、AIエージェントを使って対策を行なった上で運用していますが、その他の細かな問題については、随時Issueを起票し継続的に対応をしています。

## 補足
Railsのモジュール名が`BilingualBrog`になっているのは初期のタイポです。DB名などにも広がっていて、直すコストに見合わないためそのままにしています。
