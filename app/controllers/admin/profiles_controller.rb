module Admin
  class ProfilesController < Admin::ApplicationController
    def edit
      @user = current_user
    end

    # PATCH /admin/profile/personal — actualiza nombre y teléfono sin pedir contraseña
    def personal
      @user = current_user
      if @user.update(personal_params)
        redirect_to edit_admin_profile_path, notice: 'Datos personales actualizados.'
      else
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    # PATCH /admin/profile/password — requiere current_password para cambiar la clave
    def password
      @user = current_user
      if @user.update_with_password(password_params)
        bypass_sign_in(@user) # evita logout tras cambiar password
        redirect_to edit_admin_profile_path, notice: 'Contraseña actualizada.'
      else
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def personal_params
      params.require(:user).permit(:name, :phone)
    end

    def password_params
      params.require(:user).permit(:current_password, :password, :password_confirmation)
    end
  end
end
