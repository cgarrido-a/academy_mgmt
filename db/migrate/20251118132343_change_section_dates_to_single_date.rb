class ChangeSectionDatesToSingleDate < ActiveRecord::Migration[7.1]
  def up
    # Add new date column
    add_column :sections, :date, :date

    # Copy start_date to date (for existing records)
    Section.reset_column_information
    Section.find_each do |section|
      section.update_column(:date, section.start_date) if section.start_date.present?
    end

    # Remove old columns
    remove_column :sections, :start_date
    remove_column :sections, :end_date
  end

  def down
    # Add back the old columns
    add_column :sections, :start_date, :date
    add_column :sections, :end_date, :date

    # Copy date to start_date
    Section.reset_column_information
    Section.find_each do |section|
      if section.date.present?
        section.update_columns(start_date: section.date, end_date: section.date)
      end
    end

    # Remove the new column
    remove_column :sections, :date
  end
end
