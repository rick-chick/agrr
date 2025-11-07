# frozen_string_literal: true

class AddSourceInteractionRuleIdToInteractionRules < ActiveRecord::Migration[8.0]
  def change
    add_column :interaction_rules, :source_interaction_rule_id, :integer
    add_index :interaction_rules, [:user_id, :source_interaction_rule_id], unique: true, where: "source_interaction_rule_id IS NOT NULL"
  end
end
