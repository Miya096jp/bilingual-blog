require "application_system_test_case"

class WelcomeAuthenticationTest < ApplicationSystemTestCase
  test "ログアウト状態でトップの「ブログをはじめる」からサインアップできる" do
    visit "/ja"

    click_on "ブログをはじめる", match: :first

    within "#auth_form_frame" do
      assert_text "Create account"

      fill_in "user_username", with: "newblogger"
      fill_in "user_email", with: "newblogger@example.com"
      fill_in "user_password", with: "password123"
      fill_in "user_password_confirmation", with: "password123"
      click_on "Sign up"
    end

    assert_no_text "このページは利用できません"
    assert_text "ダッシュボードへ"
  end

  test "ログアウト状態で「ログイン」からログインできる" do
    user = users(:one)

    visit "/ja"
    click_on "ログイン", match: :first

    within "#auth_form_frame" do
      fill_in "user_email", with: user.email
      fill_in "user_password", with: "password123"
      click_on "Sign in"
    end

    assert_no_text "このページは利用できません"
    assert_text "ダッシュボードへ"
  end

  test "モーダル内でログイン/サインアップを切り替えられる" do
    visit "/ja"
    click_on "ログイン", match: :first

    within "#auth_form_frame" do
      assert_text "Sign in"
      click_on "Sign up"
      assert_text "Create account"
      click_on "Log in"
      assert_text "Sign in"
    end
  end
end
