require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  def sign_in_as(user)
    visit root_path
    click_button "Sign in"
    
    # Wait for modal to appear
    assert_selector "#auth_modal_overlay", visible: true
    
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign in", match: :first
    
    # Wait for successful login redirect
    assert_current_path dashboard_articles_path
  end
end
