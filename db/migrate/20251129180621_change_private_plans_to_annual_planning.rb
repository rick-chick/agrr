class ChangePrivatePlansToAnnualPlanning < ActiveRecord::Migration[8.0]
  def up
    # 重複チェック: 同じfarm_id × user_idで複数のplan_yearが存在するか確認
    duplicates = execute(<<-SQL.squish
      SELECT farm_id, user_id, COUNT(*) as count
      FROM cultivation_plans
      WHERE plan_type = 'private'
      GROUP BY farm_id, user_id
      HAVING COUNT(*) > 1
    SQL
    ).to_a

    if duplicates.any?
      error_message = "重複データが検出されました。マイグレーションを中止します。\n"
      error_message += "以下のfarm_id × user_idの組み合わせで複数の計画が存在します:\n"
      duplicates.each do |dup|
        error_message += "  - farm_id: #{dup['farm_id']}, user_id: #{dup['user_id']}, 計画数: #{dup['count']}\n"
      end
      raise ActiveRecord::IrreversibleMigration, error_message
    end

    # 1. plan_yearをnullableに変更
    change_column_null :cultivation_plans, :plan_year, true

    # 2. 既存の一意制約を削除
    remove_index :cultivation_plans,
                 name: 'index_cultivation_plans_on_farm_user_year_unique',
                 if_exists: true

    # 3. 新しい一意制約を追加（plan_yearを除外）
    add_index :cultivation_plans, [:farm_id, :user_id],
              unique: true,
              name: 'index_cultivation_plans_on_farm_user_unique',
              where: "plan_type = 'private'"

    # 4. plan_yearを含むインデックスの整理
    # 既存のインデックスは後方互換性のため残すが、条件を確認
    # index_cultivation_plans_on_user_plan_name_year: 既存データの検索に使用される可能性があるため残す
    # index_cultivation_plans_on_user_id_and_plan_year: 既存データの検索に使用される可能性があるため残す
  end

  def down
    # ロールバック処理
    remove_index :cultivation_plans,
                 name: 'index_cultivation_plans_on_farm_user_unique',
                 if_exists: true

    add_index :cultivation_plans, [:farm_id, :user_id, :plan_year],
              unique: true,
              name: 'index_cultivation_plans_on_farm_user_year_unique',
              where: "plan_type = 'private'"

    # plan_yearをnullableからnot nullに戻す（既存データにnullがある場合はエラーになる可能性がある）
    # 既存データのplan_yearがnullの場合は、デフォルト値を設定する必要がある
    execute(<<-SQL.squish
      UPDATE cultivation_plans
      SET plan_year = EXTRACT(YEAR FROM planning_start_date)
      WHERE plan_type = 'private' AND plan_year IS NULL
    SQL
    )

    change_column_null :cultivation_plans, :plan_year, false
  end
end

