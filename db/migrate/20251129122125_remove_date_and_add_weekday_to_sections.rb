class RemoveDateAndAddWeekdayToSections < ActiveRecord::Migration[7.1]
  def change
    remove_column :sections, :date, :date
    add_column :sections, :weekday, :string
  end
end
