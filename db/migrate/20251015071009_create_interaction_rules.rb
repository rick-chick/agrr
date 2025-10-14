# frozen_string_literal: true

class CreateInteractionRules < ActiveRecord::Migration[8.0]
  def change
    create_table :interaction_rules do |t|
      t.string :rule_type, null: false
      t.string :source_group, null: false
      t.string :target_group, null: false
      t.decimal :impact_ratio, precision: 5, scale: 2, null: false
      t.boolean :is_directional, default: true, null: false
      t.text :description

      t.timestamps
    end

    add_index :interaction_rules, [:rule_type, :source_group, :target_group], name: 'index_interaction_rules_on_type_and_groups'
    add_index :interaction_rules, :rule_type
    add_index :interaction_rules, :source_group
    add_index :interaction_rules, :target_group
  end
end

