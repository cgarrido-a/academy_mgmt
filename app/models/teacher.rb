class Teacher < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :sections, dependent: :destroy

  # Validations
  validates :user, presence: true
end
