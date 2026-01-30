# frozen_string_literal: true

class CreateBalloons < ActiveRecord::Migration[8.0]
  def change
    create_table :balloons do |t|
      t.string :name, null: false
      t.string :color, null: false, default: ''
      t.integer :size, null: false, default: 0
      t.timestamps
    end
  end
end