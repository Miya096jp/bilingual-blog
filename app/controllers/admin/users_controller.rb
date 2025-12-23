class Admin::UsersController < Admin::BaseController
  def index
    @users = User.includes(:articles).order(created_at: :desc)

    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @users = @users.where(
        "username ILIKE ? OR email ILIKE ?",
        search_term,
        search_term
      )
    end

    @users = @users.page(params[:page]).per(20)
  end

  def show
    @user = User.find(params[:id])
    @articles = @user.articles.includes(:category).order(created_at: :desc).limit(10)
  end

  def update
    @user = User.find(params[:id])

    if @user.admin?
      return redirect_to admin_users_path, alert: "管理者ユーザーの状態は変更できません"
    end

    old_status = @user.status

    if @user.update(user_params)
      action = @user.suspended? ? "停止" : "復旧"
      redirect_to admin_users_path, notice: "#{@user.username}のアカウントを#{action}しました"
    else
      redirect_to admin_users_path, alert: "操作に失敗しました"
    end
  end

  private

  def user_params
    params.require(:user).permit(:status)
  end
end
