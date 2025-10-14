# frozen_string_literal: true

class AddUserIdAndIsReferenceToInteractionRules < ActiveRecord::Migration[8.0]
  def change
    add_reference :interaction_rules, :user, foreign_key: true, null: true
    add_column :interaction_rules, :is_reference, :boolean, default: false, null: false
    
    add_index :interaction_rules, :is_reference
    add_index :interaction_rules, [:user_id, :is_reference]
  end
end

