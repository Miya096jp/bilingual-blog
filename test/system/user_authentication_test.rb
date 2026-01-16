require "application_system_test_case"

class UserAuthenticationTest < ApplicationSystemTestCase
  test "confirmed user can sign in and access dashboard" do
    user = users(:one)
    visit root_path
    click_button "Sign in"
    assert_selector "#auth_modal_overlay", visible: true
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign in", match: :first
    assert_current_path dashboard_articles_path
    assert_text "ログアウト"
  end

  test "user cannot sign in with wrong password" do
    user = users(:one)
    visit root_path
    click_button "Sign in"
    fill_in "Email", with: user.email
    fill_in "Password", with: "wrongpassword123"
    click_button "Sign in", match: :first
    assert_selector "#auth_modal_overlay"
    assert_selector ".flash-message, [role='alert']", visible: true
    visit dashboard_articles_path
    assert_no_current_path dashboard_articles_path
  end

  test "unconfirmed user cannot sign in" do
    user = users(:unconfirmed)
    visit root_path
    click_button "Sign in"
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign in", match: :first
    visit dashboard_articles_path
    assert_no_current_path dashboard_articles_path
  end

  test "user can sign out" do
    user = users(:one)
    sign_in_as(user)
    assert_text "ログアウト"
    click_link "ログアウト"
    assert_no_current_path dashboard_articles_path
    assert_button "Sign in"
    visit dashboard_articles_path
    assert_no_current_path dashboard_articles_path
  end

  test "new user can register with valid information" do
    visit root_path
    click_button "Sign in"
    click_link "Sign up"
    assert_text "Create account"
    fill_in "Username", with: "newuser123"
    fill_in "Email", with: "newuser@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    click_button "Sign up"
    assert User.exists?(email: "newuser@example.com")
    new_user = User.find_by(email: "newuser@example.com")
    assert_equal "newuser123", new_user.username
  end

  test "registration fails with duplicate email" do
    existing_user = users(:one)
    visit root_path
    click_button "Sign in"
    click_link "Sign up"
    fill_in "Username", with: "differentusername"
    fill_in "Email", with: existing_user.email
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    
    click_button "Sign up"
    assert_selector ".flash-message, [role='alert']"
    assert_equal 1, User.where(email: existing_user.email).count
  end

  test "registration fails with mismatched passwords" do
    visit root_path
    click_button "Sign in"
    click_link "Sign up"
    fill_in "Username", with: "newuser"
    fill_in "Email", with: "new@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "different123"
    
    click_button "Sign up"
    assert_selector ".flash-message, [role='alert']"
    assert_not User.exists?(email: "new@example.com")
  end

  test "modal closes when clicking outside" do
    visit root_path
    click_button "Sign in"
    assert_selector "#auth_modal_overlay", visible: true
    # Click outside the modal (on the overlay itself)
    # This tests the Stimulus controller's closeOnOutsideClick action
    find("#auth_modal_overlay").click
    assert_no_selector "#auth_modal_overlay", visible: true
  end
end
