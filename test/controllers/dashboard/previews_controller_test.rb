require "test_helper"

class Dashboard::PreviewsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:blogger)
  end

  test "Markdownをsanitize済みのHTMLに変換して返す" do
    post dashboard_preview_path, params: { content: "# Hello" }, as: :json

    assert_response :success
    assert_match %r{<h1[^>]*>Hello</h1>}, response.parsed_body["html"]
  end

  test "scriptタグやイベントハンドラ属性が出力に含まれない" do
    post dashboard_preview_path,
      params: { content: "Hi <script>alert('hack')</script> <img src=x onerror=\"alert(1)\">" },
      as: :json

    assert_response :success
    html = response.parsed_body["html"]
    assert_no_match(/<script/i, html)
    assert_no_match(/onerror/i, html)
    assert_includes html, "Hi"
  end

  test "未ログインではプレビューできない" do
    sign_out users(:blogger)
    post dashboard_preview_path, params: { content: "# Hello" }, as: :json

    assert_response :unauthorized
  end
end
