module LocaleHelper
  def locale_switch_url(target_locale)
    if action_name == "show" && @article&.translation.present?
      user_article_path(@article.translation.user.username, @article.translation.id, locale: target_locale)
    elsif action_name == "show" && @article&.original_article.present?
      user_article_path(@article.original_article.user.username, @article.original_article.id, locale: target_locale)
    elsif controller_name == "profiles" && action_name == "show"
      user_profile_path(params[:username], locale: target_locale)
    elsif controller_name == "legal"
      case action_name
      when "terms_of_service" then terms_of_service_path(locale: target_locale)
      when "privacy_policy" then privacy_policy_path(locale: target_locale)
      when "disclaimer" then disclaimer_path(locale: target_locale)
      else root_path(locale: target_locale)
      end
    elsif params[:username].present?
      user_articles_path(params[:username], locale: target_locale)
    else
      root_path(locale: target_locale)
    end
  end

  def locale_switch_label
    params[:locale] == "ja" ? "EN" : "JP"
  end

  def locale_switch_target
    params[:locale] == "ja" ? "en" : "ja"
  end
end
