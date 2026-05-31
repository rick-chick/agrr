class RemoveLocationFromFields < ActiveRecord::Migration[8.0]
  def change
    remove_column :fields, :location, :string
  end
end
