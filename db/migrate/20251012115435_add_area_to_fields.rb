class AddAreaToFields < ActiveRecord::Migration[8.0]
  def change
    add_column :fields, :area, :float
    add_column :fields, :daily_fixed_cost, :float
  end
end
