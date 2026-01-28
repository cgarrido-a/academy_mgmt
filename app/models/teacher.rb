class Teacher < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :sections, dependent: :destroy
  has_many :teacher_payments, dependent: :destroy

  # Validations
  validates :user, presence: true
end
