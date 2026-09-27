require "test_helper"
require "minitest/mock"

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

  test "変換中に例外が起きても、応答に例外のメッセージを含めない" do
    Kramdown::Document.stub(:new, ->(*) { raise "/var/secret/internal/path" }) do
      post dashboard_preview_path, params: { content: "# Hello" }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "プレビュー生成でエラーが発生しました", response.parsed_body["error"]
    assert_not_includes response.body, "/var/secret/internal/path"
  end

  test "公開ページの本文と同じHTMLを返す" do
    content = "# Hello\n\n{: .fixed .inset-0}\nparagraph\n\n```ruby\ndef x = 1\n```\n"

    post dashboard_preview_path, params: { content: content }, as: :json

    assert_response :success
    assert_equal Article.new(content: content).content_html, response.parsed_body["html"]
    assert_no_match(/fixed|inset-0/, response.parsed_body["html"])
  end
end
