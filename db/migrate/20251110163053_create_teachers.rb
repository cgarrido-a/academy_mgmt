class CreateTeachers < ActiveRecord::Migration[7.1]
  def change
    create_table :teachers do |t|
      t.string :profession
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
