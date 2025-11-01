# frozen_string_literal: true

class RenameSizeToPackageSizeInFertilizes < ActiveRecord::Migration[8.0]
  def change
    rename_column :fertilizes, :size, :package_size
  end
end

