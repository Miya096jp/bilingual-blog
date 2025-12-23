require "net/http"
require "json"
require "openssl"

class UmamiApiService
  UMAMI_BASE_URL = "https://umami-miya096jps-projects.vercel.app"
  def self.create_website_for_user(user)
    token = get_auth_token
    return unless token

    website_data = create_website(user, token)
    return unless website_data

    share_data = create_share_url(website_data["id"], token)
    return unless share_data

    share_url = "#{UMAMI_BASE_URL}/share/#{share_data['shareId']}"

    user.update!(
      umami_website_id: website_data["id"],
      umami_share_url: share_url,
      analytics_setup_completed: true
    )
  rescue => e
    Rails.logger.error "Umami setup failed for user #{user.id}: #{e.message}"
  end

  private

  def self.get_auth_token
    Rails.logger.info "🔥🔥🔥 Umami Auth Token 取得開始 🔥🔥🔥"
    uri = URI("#{UMAMI_BASE_URL}/api/auth/login")

    http = configure_http(uri)
    # http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request["User-Agent"] = "Ruby/Rails-App"
    request.body = {
      username: umami_username,
      password: umami_password
    }.to_json

    response = http.request(request)
    if response.code == "200"
      JSON.parse(response.body)["token"]
    end

    # puts "🔥#{response.code}"
    # Rails.logger.info "🔥Response body: #{response.body}"
  end

  def self.create_website(user, token)
    Rails.logger.info "🔥🔥🔥 Umami Webサイト作成開始 🔥🔥🔥"
    uri = URI("#{UMAMI_BASE_URL}/api/websites")

    http = configure_http(uri)
    # http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{token}"
    request.body = {
      name: "#{user.username} - Dual Pascal",
      domain: Rails.env.production? ? "dualpascal.com" : "localhost:3000"
    }.to_json

    response = http.request(request)
    response.code == "200" ? JSON.parse(response.body) : nil

    # puts "🔥#{response.code}"
  end

# def self.create_share_url(website_id, token)
#   Rails.logger.info "🔥🔥🔥 Share url作成開始 🔥🔥🔥"
#   uri = URI("#{UMAMI_BASE_URL}/api/websites/#{website_id}/share")
#
#   http = configure_http(uri)
#   # http.use_ssl = true
#
#   request = Net::HTTP::Post.new(uri)
#   request["Authorization"] = "Bearer #{token}"
#   request["Content-Type"] = "application/json"
#   request.body = {}.to_json
#   response = http.request(request)
#   response.code == "200" ? JSON.parse(response.body) : nil
#   puts "🔥#{response.code}"
# end
#


def self.create_share_url(website_id, token)
  Rails.logger.info "🔥🔥🔥 Share URL 有効化 (POST /api/websites/:id) 🔥🔥🔥"

  # エンドポイントから /share を削除した、サイトID直撃のURL
  uri = URI("#{UMAMI_BASE_URL}/api/websites/#{website_id}")
  http = configure_http(uri)

  # ブラウザと同じく POST を使用
  request = Net::HTTP::Post.new(uri)
  request["Authorization"] = "Bearer #{token}"
  request["Content-Type"] = "application/json"

  # 設定を更新するためのペイロード
  # shareId を含めることで、サーバー側で共有機能が有効化されます
  request.body = {
    id: website_id,
    shareId: SecureRandom.alphanumeric(10)
  }.to_json

  response = http.request(request)

  puts "🔥ステータス: #{response.code}"
  puts "🔥ボディ: #{response.body}"

  if response.code == "200" || response.code == "201"
    JSON.parse(response.body)
  else
    nil
  end
end


  def self.configure_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE  # SSL検証を無効化
    http.open_timeout = 15
    http.read_timeout = 15
    http
  end

  def self.umami_username
    Rails.application.credentials.umami[:username] || "admin"
  end

  def self.umami_password
    Rails.application.credentials.umami[:password]
  end
end
