class DropRegionsTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :regions, if_exists: true do |t|
      t.string :name, null: false
      t.string :country_code, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
      
      t.index :name, unique: true
      t.index :active
    end
  end
end
