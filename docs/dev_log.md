
# 2026-01-26

## [BUGFIX] Signupモーダルエラー (#commit-hash)

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
