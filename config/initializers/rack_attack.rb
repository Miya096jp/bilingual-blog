class Rack::Attack
  # safelist("allow-localhost") do |req|
  #   "127.0.0.1" == req.ip || "::1" == req.ip
  # end

  throttle("articles/create", limit: 5, period: 60.seconds) do |req|
    if req.path == "/dashboard/articles" && req.post?
      req.ip
    end
  end

  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.ip
    end
  end

  throttle("contacts/create", limit: 3, period: 5.minutes) do |req|
    if req.path.match?(%r{\A/(ja|en)/contacts\z}) && req.post?
      req.ip
    end
  end

  # コメントはログインなしで投稿でき即時公開されるため、ボットの連投を止める。
  throttle("comments/create", limit: 5, period: 10.minutes) do |req|
    if req.path.match?(%r{\A/(ja|en)/u/[^/]+/articles/[^/]+/comments\z}) && req.post?
      req.ip
    end
  end

  throttle("likes/create", limit: 30, period: 1.minute) do |req|
    if req.path.match?(%r{\A/(ja|en)/u/[^/]+/articles/[^/]+/likes\z}) && req.post?
      req.ip
    end
  end

  # R2 の容量と転送量を膨らませる乱用を防ぐ。ログインが必要なため、IP ではなくユーザー単位で数える。
  # Warden は Rack::Attack より前のミドルウェアなので、ここでログイン中のユーザーを参照できる。
  # 未ログインのリクエストは数えない（コントローラの authenticate_user! で弾かれる）。
  throttle("images/create/user", limit: 30, period: 1.hour) do |req|
    if req.path == "/dashboard/images" && req.post?
      req.env["warden"]&.user(:user)&.id
    end
  end

  # 以下の3つはいずれもメール送信を伴うため、厳しめの上限にしている。
  # 新規登録は入力ミスによる再送信も数えるため、他より少し緩めにしている。
  throttle("registrations/ip", limit: 10, period: 1.hour) do |req|
    if req.path == "/users" && req.post?
      req.ip
    end
  end

  throttle("passwords/ip", limit: 5, period: 1.hour) do |req|
    if req.path == "/users/password" && req.post?
      req.ip
    end
  end

  throttle("confirmations/ip", limit: 5, period: 1.hour) do |req|
    if req.path == "/users/confirmation" && req.post?
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
