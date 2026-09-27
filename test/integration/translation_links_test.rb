require "test_helper"

# 公開ページの翻訳・原文へのリンクは、リンク先が公開されている場合だけ出す
class TranslationLinksTest < ActionDispatch::IntegrationTest
  # OAuthの資格情報がない環境ではDeviseがomniauth用のURLヘルパーを定義せず、
  # レイアウトのログインモーダルが描画できないため、ダミーを定義する
  if Devise.omniauth_configs.empty?
    ArticlesController.helper(Module.new { def omniauth_authorize_path(*) = "#" })
  end

  setup do
    @user = users(:one)
    # mixed_status_ja は公開、翻訳の mixed_status_en は下書き
    @with_draft_translation = articles(:mixed_status_ja)
    @draft_translation = articles(:mixed_status_en)
    # en_updated_ja と翻訳の en_updated_en は、どちらも公開
    @with_published_translation = articles(:en_updated_ja)
    @published_translation = articles(:en_updated_en)
  end

  test "翻訳が下書きの公開記事の詳細に、翻訳へのリンクが出ない" do
    get article_path_for(@with_draft_translation)

    assert_response :success
    assert_select "a[href=?]", article_path_for(@draft_translation), count: 0
  end

  test "翻訳が公開されている記事の詳細には、翻訳へのリンクが出る" do
    get article_path_for(@with_published_translation)

    assert_response :success
    assert_select "a[href=?]", article_path_for(@published_translation)
  end

  %w[linear hero_tiles hero_list].each do |layout_style|
    test "#{layout_style} の一覧で、翻訳が下書きの記事に翻訳へのリンクが出ない" do
      @user.blog_setting.update!(layout_style: layout_style)
      # hero 系のレイアウトは先頭の記事にだけリンクを出すため、対象の記事を先頭にする
      @with_draft_translation.update!(published_at: Time.current)

      get user_articles_path(@user.username, locale: "ja")

      assert_response :success
      assert_select "a[href=?]", article_path_for(@draft_translation), count: 0
    end

    test "#{layout_style} の一覧で、翻訳が公開されている記事には翻訳へのリンクが出る" do
      @user.blog_setting.update!(layout_style: layout_style)
      @with_published_translation.update!(published_at: Time.current)

      get user_articles_path(@user.username, locale: "ja")

      assert_response :success
      assert_select "a[href=?]", article_path_for(@published_translation)
    end
  end

  test "翻訳が下書きの公開記事で、言語切替のリンクが翻訳を指さない" do
    get article_path_for(@with_draft_translation)

    assert_select "a[href=?]", user_article_path(@user.username, @draft_translation.id, locale: "en"), count: 0
    assert_select "a[href=?]", user_articles_path(@user.username, locale: "en")
  end

  test "原文が下書きの公開翻訳で、言語切替のリンクが原文を指さない" do
    draft_original = @user.articles.create!(title: "下書きの原文", content: "本文", locale: "ja", status: :draft)
    translation = @user.articles.create!(title: "Published translation", content: "Body", locale: "en", status: :published, original_article: draft_original)

    get article_path_for(translation)

    assert_response :success
    assert_select "a[href=?]", user_article_path(@user.username, draft_original.id, locale: "ja"), count: 0
    assert_select "a[href=?]", user_articles_path(@user.username, locale: "ja")
  end

  test "原文が公開されている翻訳では、言語切替のリンクが原文を指す" do
    get article_path_for(@published_translation)

    assert_response :success
    assert_select "a[href=?]", user_article_path(@user.username, @with_published_translation.id, locale: "ja")
  end

  private

  def article_path_for(article)
    user_article_path(article.user.username, article.id, locale: article.locale)
  end
end
