module Admin
  class ApplicationController < ::ApplicationController
    before_action :authenticate_user!
    before_action :verify_admin_or_teacher!
    layout 'admin'

    private

    def verify_admin_or_teacher!
      unless current_user.admin_user.present? || current_user.teacher.present?
        redirect_to unauthorized_path, alert: "No tienes permisos para acceder a esta sección."
      end
    end

    def verify_admin_only!
      unless current_user.admin_user.present?
        redirect_to unauthorized_path, alert: "Solo los administradores pueden acceder a esta sección."
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
