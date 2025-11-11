class RemoveTimeFieldsFromSections < ActiveRecord::Migration[7.1]
  def change
    remove_column :sections, :start_time, :time
    remove_column :sections, :end_time, :time
  end
end
