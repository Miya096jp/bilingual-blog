class Dashboard::AnalyticsController < ApplicationController
  before_action :authenticate_user!
  layout "dashboard"

  def index
    @has_analytics = current_user.has_analytics?
    @dashboard_url = current_user.analytics_dashboard_url
    @setup_in_progress = !current_user.analytics_setup_completed?
  end
end
