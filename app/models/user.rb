class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # :registerable removed - only admins can create users
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_one :student, dependent: :destroy
  has_one :teacher, dependent: :destroy
  has_one :admin_user, dependent: :destroy

  # Validations
  validates :name, presence: true
end
