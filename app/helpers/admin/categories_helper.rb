module Admin::CategoriesHelper
  def category_count_for_locale(locale)
    current_user.categories.for_locale(locale).count
  end
end
