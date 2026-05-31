class AddOptimizationResultsToCultivationPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :cultivation_plans, :total_profit, :decimal
    add_column :cultivation_plans, :total_revenue, :decimal
    add_column :cultivation_plans, :total_cost, :decimal
    add_column :cultivation_plans, :optimization_time, :decimal
    add_column :cultivation_plans, :algorithm_used, :string
    add_column :cultivation_plans, :is_optimal, :boolean
    add_column :cultivation_plans, :optimization_summary, :text
  end
end
