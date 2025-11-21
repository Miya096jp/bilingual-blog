module Admin::CategoriesHelper
  def category_count_for_locale(locale)
    Category.for_locale(locale).count
  end
end
