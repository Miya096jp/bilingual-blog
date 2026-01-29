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

  self.throttled_response = lambda do |env|
    now = Time.current
    match_data = env["rack.attack.match_data"]
    reset_time = match_data[:period] - (now.to_i % match_data[:period])

    [
      429, # HTTP Status Code: Too Many Requests
      { "Content-Type" => "application/json", "Retry-After" => reset_time.to_s },
      [ { error: "頻繁なリクエストを検知しました。#{reset_time}秒後に再度お試しください。" }.to_json ]
    ]
  end
end
