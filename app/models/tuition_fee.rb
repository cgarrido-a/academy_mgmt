class TuitionFee < ApplicationRecord
  belongs_to :enrollment
  belongs_to :payment_method
end
