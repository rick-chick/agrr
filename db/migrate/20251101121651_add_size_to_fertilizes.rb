class AddSizeToFertilizes < ActiveRecord::Migration[8.0]
  def change
    add_column :fertilizes, :size, :string
  end
end
