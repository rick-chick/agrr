class CreateRegions < ActiveRecord::Migration[8.0]
  def change
    create_table :regions do |t|
      t.string :name, null: false
      t.string :country_code, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :regions, :name, unique: true
    add_index :regions, :active
  end
end
