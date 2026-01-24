module Api
  module V1
    class UsersController < BaseController
      # GET /api/v1/users/find_by_email?email=xxx
      # Returns user data if found, including student_id if the user is a student
      def find_by_email
        email = params[:email]&.strip&.downcase

        if email.blank?
          return render json: {
            success: false,
            error: 'Email es requerido'
          }, status: :bad_request
        end

        user = User.find_by('LOWER(email) = ?', email)

        if user
          student = user.student

          render json: {
            success: true,
            found: true,
            data: {
              user_id: user.id,
              name: user.name,
              email: user.email,
              phone: user.phone,
              student_id: student&.id,
              is_student: student.present?
            }
          }
        else
          render json: {
            success: true,
            found: false,
            data: nil
          }
        end
      end
    end
  end
end
