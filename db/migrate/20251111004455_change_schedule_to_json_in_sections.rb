class ChangeScheduleToJsonInSections < ActiveRecord::Migration[7.1]
  def change
    # Remove old integer schedule column
    remove_column :sections, :schedule, :integer

    # Add new text column for JSON data (SQLite compatible)
    add_column :sections, :schedule, :text, default: '[]'
  end
end
