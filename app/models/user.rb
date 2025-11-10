class User < ApplicationRecord
  # Associations
  has_one :student, dependent: :destroy
  has_one :teacher, dependent: :destroy
  has_one :admin_user, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  # Note: Password validation removed. Consider implementing has_secure_password for proper authentication
end
