# frozen_string_literal: true

class RemoveBalloonsTable < ActiveRecord::Migration[8.0]
  def up
    drop_table :balloons, if_exists: true
  end

  def down
    create_table :balloons do |t|
      t.string :name, null: false
      t.string :color, null: false, default: ''
      t.integer :size, null: false, default: 0
      t.timestamps
    end
  end
end
