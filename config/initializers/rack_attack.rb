class Rack::Attack::Request
  # ルーターは末尾・連続のスラッシュや拡張子（.json など）を吸収して同じアクションに届けるため、
  # 制限の判定も同じ規則で正規化したパスで行う。そうしないとパスの書き方を変えるだけで制限を回避できる。
  # 拡張子は、ルーターの (.:format) と同じく末尾の1つだけを取り除く。
  def normalized_path
    ActionDispatch::Journey::Router::Utils.normalize_path(path).sub(%r{\.[^/.]+\z}, "")
  end

  # ログインで送られたメールアドレスを、Devise と同じ規則（前後の空白を除き、小文字にする）で正規化して返す。
  # req.params には JSON の本文が含まれないが、Rails は JSON の本文でもログインを処理するため、本文も読む。
  def login_email
    email = user_email_in(params) || user_email_in(json_body)
    return unless email.is_a?(String)

    email.strip.downcase.presence
  end

  private

  # user が Hash でない形で送られても例外にしない
  def user_email_in(hash)
    hash["user"]["email"] if hash.is_a?(Hash) && hash["user"].is_a?(Hash)
  end

  def json_body
    return unless media_type == "application/json" && body

    JSON.parse(body.read)
  rescue JSON::ParserError
    nil
  ensure
    # Rails 側のログイン処理が本文を最初から読めるよう、読んだ位置を戻す
    body&.rewind
  end
end

class Rack::Attack
  # safelist("allow-localhost") do |req|
  #   "127.0.0.1" == req.ip || "::1" == req.ip
  # end

  throttle("articles/create", limit: 5, period: 60.seconds) do |req|
    if req.normalized_path == "/dashboard/articles" && req.post?
      req.ip
    end
  end

  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    if req.normalized_path == "/users/sign_in" && req.post?
      req.ip
    end
  end

  # IP を分散させた総当たりを止めるため、同じメールアドレスへの試行を数える。
  # アカウント自体はロックせず、期間が過ぎれば解除される。OmniAuth でのログインには影響しない。
  # キャッシュのキーやログにメールアドレスを残さないよう、ハッシュ化した値をキーにする。
  throttle("logins/email", limit: 10, period: 1.hour) do |req|
    if req.normalized_path == "/users/sign_in" && req.post?
      email = req.login_email
      Digest::SHA256.hexdigest(email) if email
    end
  end

  throttle("contacts/create", limit: 3, period: 5.minutes) do |req|
    if req.normalized_path.match?(%r{\A/(ja|en)/contacts\z}) && req.post?
      req.ip
    end
  end

  # コメントはログインなしで投稿でき即時公開されるため、ボットの連投を止める。
  throttle("comments/create", limit: 5, period: 10.minutes) do |req|
    if req.normalized_path.match?(%r{\A/(ja|en)/u/[^/]+/articles/[^/]+/comments\z}) && req.post?
      req.ip
    end
  end

  throttle("likes/create", limit: 30, period: 1.minute) do |req|
    if req.normalized_path.match?(%r{\A/(ja|en)/u/[^/]+/articles/[^/]+/likes\z}) && req.post?
      req.ip
    end
  end

  # R2 の容量と転送量を膨らませる乱用を防ぐ。ログインが必要なため、IP ではなくユーザー単位で数える。
  # Warden は Rack::Attack より前のミドルウェアなので、ここでログイン中のユーザーを参照できる。
  # 未ログインのリクエストは数えない（コントローラの authenticate_user! で弾かれる）。
  throttle("images/create/user", limit: 30, period: 1.hour) do |req|
    if req.normalized_path == "/dashboard/images" && req.post?
      req.env["warden"]&.user(:user)&.id
    end
  end

  # 以下の3つはいずれもメール送信を伴うため、厳しめの上限にしている。
  # 新規登録は入力ミスによる再送信も数えるため、他より少し緩めにしている。
  throttle("registrations/ip", limit: 10, period: 1.hour) do |req|
    if req.normalized_path == "/users" && req.post?
      req.ip
    end
  end

  throttle("passwords/ip", limit: 5, period: 1.hour) do |req|
    if req.normalized_path == "/users/password" && req.post?
      req.ip
    end
  end

  throttle("confirmations/ip", limit: 5, period: 1.hour) do |req|
    if req.normalized_path == "/users/confirmation" && req.post?
      req.ip
    end
  end

  self.throttled_responder = lambda do |request|
    now = Time.current
    match_data = request.env["rack.attack.match_data"]
    reset_time = match_data[:period] - (now.to_i % match_data[:period])

    [
      429, # HTTP Status Code: Too Many Requests
      { "Content-Type" => "application/json", "Retry-After" => reset_time.to_s },
      [ { error: "頻繁なリクエストを検知しました。#{reset_time}秒後に再度お試しください。" }.to_json ]
    ]
  end
end
