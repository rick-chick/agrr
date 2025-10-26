class AddUniqueConstraintToCultivationPlans < ActiveRecord::Migration[8.0]
  def change
    # 農場とユーザと年で一意制約を追加（private計画のみ）
    add_index :cultivation_plans, [:farm_id, :user_id, :plan_year], 
              unique: true, 
              name: 'index_cultivation_plans_on_farm_user_year_unique',
              where: "plan_type = 'private'"
  end
end
