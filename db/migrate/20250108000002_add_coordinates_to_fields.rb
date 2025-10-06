# frozen_string_literal: true

class AddCoordinatesToFields < ActiveRecord::Migration[8.0]
  def change
    add_column :fields, :latitude, :decimal, precision: 10, scale: 8
    add_column :fields, :longitude, :decimal, precision: 11, scale: 8
  end
end

