module Admin
  class ApplicationController < ::ApplicationController
    before_action :authenticate_user!
    before_action :check_admin_or_teacher_access!
    layout 'admin'

    # CanCanCan exception handling
    rescue_from CanCan::AccessDenied do |exception|
      redirect_to unauthorized_path, alert: exception.message
    end

    private

    def check_admin_or_teacher_access!
      unless current_user.admin_user.present? || current_user.teacher.present?
        redirect_to unauthorized_path, alert: "No tienes permisos para acceder a esta sección."
      end
    end

    def current_admin?
      current_user.admin_user.present?
    end

    def current_teacher?
      current_user.teacher.present?
    end

    helper_method :current_admin?, :current_teacher?
  end
end
