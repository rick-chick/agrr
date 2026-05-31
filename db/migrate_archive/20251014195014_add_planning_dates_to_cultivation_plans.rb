class AddPlanningDatesToCultivationPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :cultivation_plans, :planning_start_date, :date
    add_column :cultivation_plans, :planning_end_date, :date
  end
end
