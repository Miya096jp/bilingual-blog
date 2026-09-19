require "test_helper"

class Dashboard::ProfilesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:blogger)
    sign_in @user
  end

  test "編集画面に新しい入力欄が表示される" do
    get edit_dashboard_profile_path

    assert_response :success
    assert_select "input[type=file][name=?]", "user[avatar]"
    assert_select "input[type=file][name=?]", "user[portrait]"
    assert_select "input[name=?]", "user[nickname_ja]"
    assert_select "input[name=?]", "user[nickname_en]"
    assert_select "textarea[name=?][data-markdown-preview-target=input]", "user[profile_body_ja]"
    assert_select "textarea[name=?][data-markdown-preview-target=input]", "user[profile_body_en]"
  end

  test "本文欄はWrite/Previewのタブで切り替えられる" do
    get edit_dashboard_profile_path

    assert_response :success
    assert_select "[data-controller~=tabs]", count: 2
    assert_select "[role=tab][data-tabs-name=write][aria-selected=true]", count: 2
    assert_select "[role=tab][data-tabs-name=preview][aria-selected=false]", count: 2
    assert_select "[role=tabpanel][data-tabs-name=write] textarea[data-markdown-preview-target=input]", count: 2
    assert_select "[role=tabpanel][data-tabs-name=preview][hidden] [data-markdown-preview-target=preview]", count: 2
  end

  test "編集画面から旧プロフィール項目が外れている" do
    get edit_dashboard_profile_path

    assert_response :success
    %w[bio_ja bio_en location_ja location_en website twitter_handle facebook_handle
       linkedin_handle github_handle qiita_handle zenn_handle hatena_handle].each do |field|
      assert_select "[name=?]", "user[#{field}]", count: 0
    end
  end

  test "プロフィール本文を更新できる" do
    patch dashboard_profile_path, params: { user: { profile_body_ja: "# 日本語", profile_body_en: "# English" } }

    assert_redirected_to edit_dashboard_profile_path
    @user.reload
    assert_equal "# 日本語", @user.profile_body_ja
    assert_equal "# English", @user.profile_body_en
  end

  test "ポートレートをアップロードできる" do
    file = fixture_file_upload("portrait.png", "image/png")
    patch dashboard_profile_path, params: { user: { portrait: file } }

    assert_redirected_to edit_dashboard_profile_path
    assert @user.reload.portrait.attached?
  end

  test "旧プロフィール項目は更新されない" do
    patch dashboard_profile_path, params: { user: { bio_ja: "変更", website: "https://example.com", github_handle: "x" } }

    @user.reload
    assert_equal "Ruby と Rails が好きです", @user.bio_ja
    assert_nil @user.website
    assert_nil @user.github_handle
  end
end
