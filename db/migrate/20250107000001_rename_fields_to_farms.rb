# frozen_string_literal: true

class RenameFieldsToFarms < ActiveRecord::Migration[8.0]
  def change
    rename_table :fields, :farms
  end
end


