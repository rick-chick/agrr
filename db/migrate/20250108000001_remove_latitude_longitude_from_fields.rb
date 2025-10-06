# frozen_string_literal: true

class RemoveLatitudeLongitudeFromFields < ActiveRecord::Migration[8.0]
  def change
    remove_column :fields, :latitude, :decimal, precision: 10, scale: 8
    remove_column :fields, :longitude, :decimal, precision: 11, scale: 8
  end
end
