require "application_system_test_case"

class LikeFunctionalityTest < ApplicationSystemTestCase
  def setup
    @user = users(:one)
    @article = articles(:published_ja)
  end

  test "logged in user can like an article" do
    sign_in_as(@user)
    initial_count = @article.likes_count || 0
    visit user_article_path(@article.user.username, @article.id, locale: "ja")
    within("#like_button_#{@article.id}") do
      click_button class: "like-btn"
    end
    assert @article.likes.exists?(user_id: @user.id)
    @article.reload
    assert_equal initial_count + 1, @article.likes_count
  end

  test "logged in user can unlike an article" do
    sign_in_as(@user)
    Like.create!(user: @user, article: @article)
    @article.reload
    initial_count = @article.likes_count
    visit user_article_path(@article.user.username, @article.id, locale: "ja")
    within("#like_button_#{@article.id}") do
      click_button class: "like-btn liked"
    end
    
    assert_not @article.likes.exists?(user_id: @user.id)
    @article.reload
    assert_equal initial_count - 1, @article.likes_count
  end

  test "visitor cannot like article when not logged in" do
    visit user_article_path(@article.user.username, @article.id, locale: "ja")
    within("#like_button_#{@article.id}") do
      assert_selector "button[disabled]"
    end
  end

  test "user cannot like same article twice" do
    sign_in_as(@user)
    Like.create!(user: @user, article: @article)
    visit user_article_path(@article.user.username, @article.id, locale: "ja")
    initial_like_count = Like.where(user: @user, article: @article).count
    
    within("#like_button_#{@article.id}") do
      assert_selector ".like-btn.liked"
      find(".like-btn").click 
    end

    assert_equal 0, Like.where(user: @user, article: @article).count
  end
end
