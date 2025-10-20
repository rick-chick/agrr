class AddPrivatePlanFieldsToCultivationPlans < ActiveRecord::Migration[8.0]
  def change
    # 計画タイプ: 'public'（無料計画）or 'private'（個人計画）
    add_column :cultivation_plans, :plan_type, :string, default: 'public', null: false
    # 計画名（将来的に複数の計画名簿を管理）
    add_column :cultivation_plans, :plan_name, :string
    # 計画年度（2025, 2026...）
    add_column :cultivation_plans, :plan_year, :integer
    
    # インデックス追加
    add_index :cultivation_plans, :plan_type
    add_index :cultivation_plans, [:user_id, :plan_year], where: "plan_type = 'private'"
    add_index :cultivation_plans, [:user_id, :plan_name, :plan_year], name: 'index_cultivation_plans_on_user_plan_name_year', where: "plan_type = 'private'"
  end
end
