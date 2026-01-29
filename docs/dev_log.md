open template: dlt
copy full path: space + c + P
show today's doc: todaydoc



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







