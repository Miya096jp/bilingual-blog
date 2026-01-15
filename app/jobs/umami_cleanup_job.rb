class UmamiCleanupJob < ApplicationJob
  queue_as :default

  def perform(website_id)
    return if website_id.blank?

    UmamiApiService.delete_website(website_id)
  end
end
