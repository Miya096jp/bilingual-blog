require "test_helper"

class DashboardArticleListQueryTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "日本語タイトルの部分一致で該当ペアの原文がヒットする" do
    query = DashboardArticleListQuery.new(user: @user, params: { q: "学習ノート" })

    assert_equal [ articles(:search_target_ja) ], query.call.to_a
  end

  test "英語(翻訳)タイトルの部分一致でも該当ペアの原文がヒットする" do
    query = DashboardArticleListQuery.new(user: @user, params: { q: "Study Notes" })

    assert_equal [ articles(:search_target_ja) ], query.call.to_a
  end

  test "status: draft は日英いずれかが下書きのペアを返す" do
    query = DashboardArticleListQuery.new(user: @user, params: { status: "draft" })

    assert_includes query.call.to_a, articles(:mixed_status_ja)
    assert_includes query.call.to_a, articles(:test_article)
    assert_not_includes query.call.to_a, articles(:search_target_ja)
  end

  test "status: published は日英とも公開のペアのみを返す" do
    query = DashboardArticleListQuery.new(user: @user, params: { status: "published" })

    assert_includes query.call.to_a, articles(:search_target_ja)
    assert_not_includes query.call.to_a, articles(:mixed_status_ja)
    assert_not_includes query.call.to_a, articles(:en_original_no_translation)
  end

  test "status: no_translation は翻訳が存在しない原文のみを返す(原文の言語を問わない)" do
    query = DashboardArticleListQuery.new(user: @user, params: { status: "no_translation" })

    result = query.call.to_a
    assert_includes result, articles(:test_article)
    assert_includes result, articles(:en_original_no_translation)
    assert_not_includes result, articles(:search_target_ja)
  end

  test "既定の並び替えはペアのうち新しいほうのupdated_atが新しい順になる(英語だけ更新したペアが上位に来る)" do
    query = DashboardArticleListQuery.new(user: @user, params: {})

    result = query.call.to_a
    en_updated_index = result.index(articles(:en_updated_ja))
    search_target_index = result.index(articles(:search_target_ja))

    assert en_updated_index < search_target_index
  end

  test "sort: created_asc は原文記事のcreated_atの昇順になる" do
    query = DashboardArticleListQuery.new(user: @user, params: { sort: "created_asc" })

    result = query.call.to_a
    en_updated_index = result.index(articles(:en_updated_ja))
    search_target_index = result.index(articles(:search_target_ja))

    assert en_updated_index < search_target_index
  end

  test "filter_params は空の値を除いたハッシュを返す" do
    query = DashboardArticleListQuery.new(user: @user, params: { q: "テスト", status: "", sort: "created_asc" })

    assert_equal({ q: "テスト", sort: "created_asc" }, query.filter_params)
  end

  test "filtering? はqかstatusが指定されている場合にtrueを返す" do
    assert DashboardArticleListQuery.new(user: @user, params: { q: "テスト" }).filtering?
    assert DashboardArticleListQuery.new(user: @user, params: { status: "draft" }).filtering?
    assert_not DashboardArticleListQuery.new(user: @user, params: {}).filtering?
  end
end
