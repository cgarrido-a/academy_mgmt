class AddGuardianContactToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :guardian_email, :string
    add_column :users, :guardian_phone, :string
  end
end
