open template: dlt
copy full path: space + c + P
show today's doc: todaydoc

# 2026-02-10

## [BUG] SMTPサーバーをAWS SESからResendに変更
(614355f18eabfd73668d5627f01da0d8213718fe: Change SMTP server from AWS SES to Resend)

### 概要
- AWS SESの申請却下
- resendに登録しclaudflareにDNS設定

### 補足
- 迷惑メールに届く。ルートドメインにSPFを追加。翌日の動作確認予定

### 関連Doc
resend-gem-dns-settings-rails-config.md

---

# 2026-02-08

## [BUG] hero_listレイアウトのカテゴリー表示を修正
(754c010d6db941400c6f36e45668f26f3c00a5d4: Fix category rendering in the hero list layout)

### 概要
typoによるレンダリング不良を修正


## [FEATURE] OGPを追加する
(fb37eb432fef96d705e158cbf12f3176e0e0439f: Add OGP configuration and default images)

### 概要
- articleにdescritionを追加できるようにした
- 記事のカバーイメージをOGP画像として表示できる様にした

### 補足
- 現在はユーザーのトップのOGP画像はdualpascal_official_imageになっているが、将来的にそれぞれのユーザーのヘッダー画像を表示できるようにする

### 技術詳細
./Knowledge/Tech/Frontend/imprement-description-form.md

---

# 2026-02-07

## [BUG] OmniAuthの本番環境設定不備
(21722d29e54a12f22d6a51e49a472de6bb9f2003: Change auth settings for production)

- github, googleそれぞれ本番環境用のOuth App登録
- credential.yamlの修正。development, production配下にそれぞれのclientidとsecretidを記述
- devise側修正、digで環境ごとに呼び出し変更
- config.force_ssl = trueに修正


関連Docs:
./Knowledge/Tech/Infra/change-auth-settings-for-production.md


## [CHORE] meta-tag Gemのインストール

(d371895e5e140ec7812b7b6e12bc726359de812c:  Install meta-tag gem)

- OGPの実装のためにインストール
- OmniAuthの本番環境設定不備が発覚したため、実装は後回し。HOSTとvpsの齟齬が出るのが嫌なので、これだけ先にコミット


---

# 2026-02-03


## [CHORE] Aboutページをロケール対応にする

(dc9502e09f3e68f6da08a5d4d84d82ec63419a22: Localized About page)

### 技術詳細:
~/Documents/Knowledge/Tech/Architecture/implement-about-page-in-dual-pascal.md


## [CHORE] ヘッダーのニックネーム表示をロケールにより切り替え

(fdf34285674e7ba639d8d65e25c5dbd755191923: Display localized nickname on header)



# 2026-02-02

## [FEATURE] LPのヘッダーにAboutページへのリンクを追加し、Adminのプロフィールは非表示に変更

(b64842d9f79515acd9d84a834c4c242367523578: Implement About page and update header navigation)

## [CHORE] Indexページの"Category:"直後に半角スペースを挿入

(1e0cbfda44c764da4fa5f6d512f75e6d2da700dc: Insert a space to the category item in the index layouts)


## [CHORE] 本文に挿入した画像を右寄せにする

(a8b8f92eac573731a38191d631e700b390b2b1c4: Aligh images in the body to the light)


## [CHORE] iframeの高さをumamiのアクセス解析ページの高さに合わせて修正

(6181b85901761669abfe8dd64e29da691f5ecf4b: Adjust the umami iframe height)


## [BUG] Showページにカバー画像を表示する様に修正

(0b8b42bfd83bc6dd6ed679e6d2b101eb86252921: Display a cover image in a show pege if it exists)

## [CHORE] クライアントfooterにルートパスへのリンクを追加する
(8a68d9d0f694835e3b5881b57930a1e927d92eaa: Link the dualpascal logo in the copyright line to lp)



## [CHORE] adminのヒーローページ下部に海外閲覧者への注釈を追加
(cfa3fb10116ed4ed1b868a0e0b47125763bbb513: Add an annotation for English-speaking visitors in hero tiles view)

---

# 2026-02-01

## DEPLOY
- デプロイ
- 作業を
- 箇条書き


# 2026-01-31



## [DEPLOY] 
(Add an umami monitering script in layouts/applications.html.erb: 3bbfead26e38c5744c3828fb9a5442b97b221ca9)

### 概要
- Umamiセットアップ
- vpsにworkerを追加
- 環境変数設定

### 補足
- Umamiアクセス解析はユーザー登録時自動作成、Dashboardに表示
- tracking codeをクライアント側に埋め込むも訪問数追加されず。直接叩いても404 NOT Found
- vercelのrebuild等でも変わらず、環境変数問題なし
- 明日原因を究明予定

### 技術詳細
- ./Knowledge/Tech/Infra/upscale-sakura-install-ubunto-setup-ssl.md


## [DEPLOY] zeitwerkのエラー 
(Add SES smtp settings: 8622aca924f510b3bd17089e832a24004ee628f2)

### 概要
- AWS SES登録, DNS設定
- railsのenvironment/production.rb main関連設定
- deviseメール送信ドメイン設定

### 技術詳細
- ./Knowledge/Tech/Infra/upscale-sakura-install-ubunto-setup-ssl.md


## [DEPLOY] その他

### 概要
- WebサーバーはCaddyを導入
- Claudflare domain(dualpascal.com)のDNS設定完了

### 技術詳細
- ./Knowledge/Tech/Infra/upscale-sakura-install-ubunto-setup-ssl.md




# 2026-01-30

## [DEPLOY] zeitwerkのエラー 
  (706efd788f6d668f217fba6c10c5e4287b118c0c: Fix inconsistency in dashboard attachments naming)
  (ec088f4734291134e0525902aff401e1c7446928: Fix inconsistency between class name of users)

### 概要
- AttachentsController => Dashboard::AttachmentsController
- Users/CommentsController => Controllers/CommentsController

controller, routes, pathの不整合を修正

### 技術詳細
- ./Knowledge/Tech/Infra/zeitwerk.md
- ./Knowledge/Tech/Ruby/routing-and-autoload-rails.md

---

## [DEPLOY] 
(2b07ebd54d75d91278fdad77a71e11e9640182d0: Skip OmniAuth config if credentials are missing)

### 概要
- assets:precompileの際にRailsは設定ファイル（`config/initializers/devise.rb`）を読み込みOmniAuthログイン設定をしようとするが、Dockerビルド中はDockerビルド中暗号化された認証情報（credentials.yml.enc）が開けないことが原因
- 認証情報がない時は設定をスキップするように条件追加

### 技術詳細
- ./Knowledge/Tech/Infra/upscale-sakura-install-ubunto-setup-ssl.md

---

## [DEPLOY]  
(47c0d1b194b1a9899d3adc272dbd94aef1da094f: Read umami credentials from .env prior to credentials.yml.enc)

### 概要
- vpsの.envにumamiのuser, pass, url記述
- umamiのデプロイ先vercelの環境変数にipアドレス, domainを追加
- umamiのアクセス解析ブラウザで表示確認

### 補足
- この他、claudflare r2の本番用バケットを追加
- .envに記述し、ブラウザで画像の表示を確認

### 技術詳細
- ./Knowledge/Tech/Infra/upscale-sakura-install-ubunto-setup-ssl.md
./Knowledge/Tech/Infra/create-new-backet-of-claudflare-r2.md
./Knowledge/Tech/Infra/production-rails-c-settings.md
./Knowledge/Tech/Infra/upscale-sakura-install-ubunto-setup-ssl.md
./Knowledge/Tech/Infra/aws-sdk-requires-endpoints-to-be-HTTPS.md

---

# 2026-01-29

## [DEPLOY] dual pascal初のデプロイ(d97bbbe2f0961132b249a8b965323887c5032390)

### 概要
- sakura vps 512 => 1Gにupscale
- swapし仮想2G、合計3Gの運用
- 807円/月
- Ubunto 24.04
- domain: dualpascal.com (claudflare)

### 補足
- deploy完了 (admin作成後ブラウザ動作確認予定)
- domain未設定
- claudflare R2本番用backet要取得
- umami 本番ドメイン要登録

### 技術詳細
- ./Knowledge/Tech/Infra/upscale-sakura-install-ubunto-setup-ssl.md 


---

## [FEATURE] rack-attackを追加 (049ea6fc8449c9fa4ab0071a2c247d127f040bba)

### 概要
- 一度に大量のリクエストがあった場合に備えてrack-attack追加
- 6回の連続リクエストに対し429エラー

### 目的
- セキュリティ強化

### 補足
- 前回コミットに関連する修正とgemのインストールを含む

### 技術詳細
./Knowledge/Tech/Ruby/implement-rack-attack-rack-middleware-overview.md

---


## [FEATURE] Actieve storage varidationsを追加 (049ea6fc8449c9fa4ab0071a2c247d127f040bba)

### 概要
- images, cover_images, avatarにvaridation追加

### 目的
- 画像拡張子、容量制限のため

### 技術詳細
./Knowledge/Tech/Ruby/add-active-storage-image-varidation.md
./Knowledge/Tech/Ruby/active-storage-101.md

---
# 2026-01-28

## CHORE(2e3f09467f64652de7bc2e5dcfac57796c9f0be7)
クライアントレイアウトによらず、カバーイメージを表示するように変更

### 変更前
- linearレイアウトにおいてカバーアイメージが表示されていなかった
- カバーイメージのサイズが適切でなかった
- ブログ設定でカバーイメージの表示・非表示の切り替えチェックボックスが存在
- ブログタイトルと本文の間に不要なドット表示があった

### 変更後
- 全てのレイアウトでカバーアイメージを表示した
- カバーイメージのサイズを適切に調整した
- カバーアイメージを常に表示するように変更
- ブログタイトルと本文の不要なドットを排除し、余白を設けた

### 影響範囲
- クライアントのインデックスページ
- ダッシュボードのブログ設定ページ

### 技術詳細
./Knowledge/Tech/Frontend/CSS/modernize-dual-pascal-client-view.md

---

## BUGFIX モーダルオープン時に必ずLoginフォームを表示するように変更(e70c69a6a760c5becf60feb7d816bf9264f65f42)

### 問題
- Signupでバリデーションエラーが出た後、モーダルを閉じて再度開くと、Signupフォームが開き, フォームフィールドに値が残ったままになる

### 期待動作
- フォームフィールドの値が消える
- もしくはログインフォームが開く

### 原因
- Stimulusで値のリセットをしていなかった
- モーダルを開いた時にどのフォームを表示するか指定していなかった

### 解決策
- uxを検討し、ログインフォームを必ず表示するように変更。

### 影響範囲
- ログインモーダル

### 補足
- ユーザーモデルにユーザー名のバリデーションを追加

### 技術詳細
- ./Knowledge/Tech/Frontend/Stimulus/show-login-form-when-reopen-modal-after-signup-varidation-fails.md
- ./Knowledge/Tech/Frontend/Stimulus/stimulus-101.md
- ./Knowledge/Tech/Frontend/Hotwire/redirect-issue-devise-respond_with-vs-response_to.md



---

# 2026-01-27

## [BUGFIX] public/assetsによるJS不具合 (27aaecc2)

### 問題
- Stimulusのコードに不具合がないがモーダルが動かない
- 通常リンク全てクリック時無反応・新しいタブでは開ける

### 原因
- キャッシュの問題
- public/assetsの影響

### 解決策
- rm -rf public/assets
- 強力キャッシュクリア: cmd + shift + r
- サーバー再起動

### 影響範囲
- クライアント側ビュー全て
- dashboardは正常(auth_modalがないため)

### 補足
- 問題切り分けのためlocalで起動したが、その場合もrailsはソースコードでなくpublic/assetsを読みに行く
- docker化の試行錯誤でasset:precompileを実行したことが原因
- 今後誤って作成した場合は即削除

### 技術詳細
 /Users/miya/Documents/Knowledge/Tech/Infra/mac-docker-db-conflict.md
 /Users/miya/Documents/Knowledge/Tech/Infra/unwanted-effects-of-assets-precompile.md
 /Users/miya/Documents/Knowledge/Tech/Frontend/Stimulus/js-not-applied-due-to-public-assets.md

---

## [FEATURE] 未使用blobs削除のためのrakeタスク実装 (083170c6a1c90a08bab4b754ef7f3a75423b84c4)

### 概要
- 毎晩定期的に未使用の画像を削除する

### 目的
- Cloudflare R2容量の節約
- 削除統計モニタリングによるバグの早期発見

### 補足
- コード実装完了
- 動作確認前にpublic/assetsによるビューのエラーのため、確認は持ち越し

### 技術詳細
/Users/miya/Documents/Knowledge/Tech/Ruby/rake-task-101.md
/Users/miya/Documents/Knowledge/Tech/Ruby/rails-logger-101.md
/Users/miya/Documents/Knowledge/Tech/Ruby/rails-cron-job-101.md
/Users/miya/Documents/Knowledge/Tech/Ruby/delete-unattached-blob-by-scheduled-rake-task.md


---

# 2026-01-26

## [BUGFIX] Signupモーダルエラー (#60b4e01e)

### 問題
- Signupでバリデーションエラーになった場合にモーダルが閉じて通常の画面にリダイレクトされる

### 期待動作
- モーダルにエラーメッセージが表示される

### 原因
- formのデータ属性 data: { turbo: "false" } の影響

### 解決策
- data: { turbo_frame: "_top" }に修正

### 影響範囲
- モーダルのSignupフォーム

### 補足
- turbo: falseはturbo streamを無効化してしまう
- モーダル内でのエラー表示にはturbo streamが必要

### 技術詳細
 /Users/miya/Documents/Knowledge/Tech/Ruby/return-turbo_steam-when-login-fails.md

---







