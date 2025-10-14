# frozen_string_literal: true

class AddGroupsToCrops < ActiveRecord::Migration[8.0]
  def change
    add_column :crops, :groups, :text
  end
end

