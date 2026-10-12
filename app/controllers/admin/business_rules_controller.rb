module Admin
  # Pantalla "Reglas": una sola fila de configuración (BusinessRule.current).
  class BusinessRulesController < Admin::ApplicationController
    before_action :set_business_rule

    def edit
    end

    def update
      if @business_rule.update(business_rule_params)
        redirect_to edit_admin_business_rules_path, notice: 'Reglas actualizadas exitosamente.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_business_rule
      @business_rule = BusinessRule.first_or_create!
      authorize! :manage, @business_rule
    end

    def business_rule_params
      params.require(:business_rule).permit(:max_days_ahead_for_start, :seat_hold_days)
    end
  end
end
