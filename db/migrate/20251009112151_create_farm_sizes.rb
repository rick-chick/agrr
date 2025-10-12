class CreateFarmSizes < ActiveRecord::Migration[8.0]
  def change
    create_table :farm_sizes do |t|
      t.string :name, null: false
      t.integer :area_sqm, null: false
      t.integer :display_order, default: 0, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :farm_sizes, :display_order
    add_index :farm_sizes, :active
  end
end
