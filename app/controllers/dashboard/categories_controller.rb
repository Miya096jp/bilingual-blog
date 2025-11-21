class Dashboard::CategoriesController < ApplicationController
  before_action :set_category, only: %w[show edit update destroy]
  before_action :authenticate_user!
  layout "dashboard"

  def index
    @ja_categories = current_user.categories.for_locale("ja").with_article_count.order(:name)
    @en_categories = current_user.categories.for_locale("en").with_article_count.order(:name)
  end

  def show
  end

  def new
    @category = current_user.categories.build
    @category.locale = params[:locale] || "ja"
  end

  def create
    @category = current_user.categories.build(category_params)
    @category.locale = params[:locale]

    respond_to do |format|
      if @category.save
        format.html { redirect_to dashboard_categories_path(locale: params[:locale]), notice: "カテゴリが作成されました" }
        format.json { render json: { category: { id: @category.id, name: @category.name } } }
      else
        format.html { render new }
        format.json { render json: { error: @category.errors.full_messages.join(", ") }, status: 422 }
      end
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to dashboard_categories_path(locale: params[:locale]), notice: "カテゴリが更新されました"
    else
      render :edit
    end
  end

  def destroy
    @category.destroy
    redirect_to dashboard_categories_path(locale: params[:locale]), notice: "カテゴリが削除されました"
  end

  private

  def set_category
    @category = current_user.categories.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :description, :locale)
  end
end
