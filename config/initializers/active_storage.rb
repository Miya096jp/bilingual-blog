# direct upload はこのアプリでは使っていないが、Active Storage が標準でルートを用意しており、
# 未ログインでも blob を作成してストレージへの署名付き URL を得られてしまうため、404 を返して無効にする。
# config.active_storage.draw_routes = false は画像表示用のルートまで消えるので使わない。
# CSRF の検証より前に返すため prepend_before_action にしている。
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.prepend_before_action { head :not_found }
end
