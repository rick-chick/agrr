class RemovePestIdFromPests < ActiveRecord::Migration[8.0]
  def change
    remove_index :pests, :pest_id, if_exists: true
    remove_column :pests, :pest_id, :string
  end
end
