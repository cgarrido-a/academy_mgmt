class RemoveScheduleFromSectionsAndAddTimeFields < ActiveRecord::Migration[7.1]
  def change
    remove_column :sections, :schedule, :integer
    add_column :sections, :start_time, :time
    add_column :sections, :end_time, :time
  end
end
