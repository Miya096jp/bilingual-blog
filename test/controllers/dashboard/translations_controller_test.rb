require "test_helper"

class Dashboard::TranslationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:blogger)
    @original = articles(:published_ja)
    @translation = articles(:published_en)
    sign_in @user
  end

  test "カバー画像をファイルでアップロードできる" do
    file = fixture_file_upload("portrait.png", "image/png")
    patch dashboard_article_translation_path(@original), params: { article: { cover_image: file } }

    assert_redirected_to dashboard_articles_path
    assert @translation.reload.cover_image.attached?
  end

  test "カバー画像にsigned_idの文字列を送っても添付されない" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(file_fixture("portrait.png")),
      filename: "portrait.png",
      content_type: "image/png"
    )

    patch dashboard_article_translation_path(@original), params: { article: { cover_image: blob.signed_id } }

    assert_not @translation.reload.cover_image.attached?
  end

  test "他人のカテゴリを指定して翻訳を作成すると、保存されない" do
    assert_no_difference "Article.count" do
      post dashboard_article_translation_path(articles(:draft_ja)), params: { article: { title: "Draft", content: "Body", category_id: categories(:technology_en).id } }
    end
  end

  test "自分のカテゴリを指定して翻訳を作成すると、保存される" do
    category = @user.categories.create!(name: "Programming", locale: "en")

    assert_difference "Article.count", 1 do
      post dashboard_article_translation_path(articles(:draft_ja)), params: { article: { title: "Draft", content: "Body", category_id: category.id } }
    end
    assert_equal category, articles(:draft_ja).reload.translation.category
  end

  test "他人のカテゴリを指定して翻訳を更新すると、保存されない" do
    patch dashboard_article_translation_path(@original), params: { article: { category_id: categories(:technology_en).id } }

    assert_nil @translation.reload.category
  end

  test "自分のカテゴリを指定して翻訳を更新すると、保存される" do
    category = @user.categories.create!(name: "Programming", locale: "en")

    patch dashboard_article_translation_path(@original), params: { article: { category_id: category.id } }

    assert_redirected_to dashboard_articles_path
    assert_equal category, @translation.reload.category
  end
end
