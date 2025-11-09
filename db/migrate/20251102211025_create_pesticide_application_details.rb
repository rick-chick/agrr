# frozen_string_literal: true

class CreatePesticideApplicationDetails < ActiveRecord::Migration[8.0]
  def change
    create_table :pesticide_application_details do |t|
      t.references :pesticide, null: false, foreign_key: true
      t.string :dilution_ratio
      t.float :amount_per_m2
      t.string :amount_unit
      t.string :application_method
      
      t.timestamps
    end
  end
end








