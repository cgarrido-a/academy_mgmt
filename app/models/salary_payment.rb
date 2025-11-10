class SalaryPayment < ApplicationRecord
  belongs_to :teacher
  belongs_to :payment_method
end
