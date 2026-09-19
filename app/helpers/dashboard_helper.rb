module DashboardHelper
  def dashboard_nav_active?(*controller_paths)
    controller_paths.include?(controller.controller_path)
  end
end
