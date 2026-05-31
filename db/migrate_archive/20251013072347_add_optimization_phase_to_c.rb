class AddOptimizationPhaseToC < ActiveRecord::Migration[8.0]
  def change
    add_column :cultivation_plans, :optimization_phase, :string
    add_column :cultivation_plans, :optimization_phase_message, :text
  end
end
