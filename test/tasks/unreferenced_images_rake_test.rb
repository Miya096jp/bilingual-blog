require "test_helper"
require "rake"

class UnreferencedImagesRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("images:list_unreferenced")
    Rake::Task["images:list_unreferenced"].reenable
  end

  test "確認用タスクは何も削除せず、候補を本文に埋め込まれる形式の URL で出力する" do
    unused_image = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("portrait.png").open,
      filename: "portrait.png",
      content_type: "image/png"
    )
    unused_image.update_columns(created_at: 8.days.ago)

    output = nil
    assert_no_difference "ActiveStorage::Blob.count" do
      output, = capture_io { Rake::Task["images:list_unreferenced"].invoke }
    end

    assert ActiveStorage::Blob.exists?(unused_image.id)
    assert_includes output, "/rails/active_storage/representations/redirect/#{unused_image.signed_id}/"
  end
end
