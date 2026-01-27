open template: dlt
copy full path: space + c + P

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

## [FEATURE] 未使用blobs削除のためのrakeタスク実装 (#commit-hash)

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







