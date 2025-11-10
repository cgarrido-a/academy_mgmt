class Enrollment < ApplicationRecord
  belongs_to :student
  belongs_to :payment_plan
  belongs_to :section
  belongs_to :payment_method
end
