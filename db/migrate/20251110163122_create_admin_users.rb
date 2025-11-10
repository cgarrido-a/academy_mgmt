class CreateAdminUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_users do |t|
      t.string :admin_type
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
