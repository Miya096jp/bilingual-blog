class UmamiSetupJob < ApplicationJob
  queue_as :default

  def perform(user)
    UmamiApiService.create_website_for_user(user)
  end
end
