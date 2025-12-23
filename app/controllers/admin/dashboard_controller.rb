class Admin::DashboardController < Admin::BaseController
  def index
    @stats = {
      total_users: User.count,
      total_articles: Article.count,
      published_articles: Article.published.count,
      this_month_users: User.where(created_at: Time.current.beginning_of_month..).count,
      total_contacts: Contact.count,
      unresolved_contacts: Contact.where(resolved: false).count
    }
  end
end
