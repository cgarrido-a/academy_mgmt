class AdminUser < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :user, presence: true
end
