# frozen_string_literal: true

namespace :backward_compatibility do
  desc 'Check production/DB data for backward compatibility cleanup decisions'
  task check: :environment do
    puts '=== 後方互換性整理のためのデータ確認 ==='
    puts "Environment: #{Rails.env}"
    puts ''

    # free_crop_plans 残存確認
    free_crop_plans_count = ActiveRecord::Base.connection.execute(
      'SELECT COUNT(*) AS cnt FROM free_crop_plans'
    ).first['cnt'].to_i
    puts "1. free_crop_plans: #{free_crop_plans_count} 件"
    if free_crop_plans_count.zero?
      puts '   → FreeCropPlan 関連の削除を検討可能'
    else
      puts '   → FreeCropPlan 関連は維持必要（データ残存）'
    end
    puts ''

    # cultivation_plans の plan_year 分布（SQLite: 0/1, PostgreSQL: f/t）
    puts '2. cultivation_plans (plan_type=private) の plan_year 分布:'
    result = ActiveRecord::Base.connection.execute(<<~SQL)
      SELECT (plan_year IS NOT NULL) AS has_plan_year, COUNT(*) AS cnt
      FROM cultivation_plans
      WHERE plan_type = 'private'
      GROUP BY (plan_year IS NOT NULL)
    SQL
    plan_year_set_count = 0
    result.each do |row|
      has_plan_year = row['has_plan_year']
      count = row['cnt'].to_i
      # SQLite returns 0/1, PostgreSQL returns false/true
      is_set = [1, true, '1', 't'].include?(has_plan_year)
      label = is_set ? 'plan_year あり' : 'plan_year なし (null)'
      puts "   #{label}: #{count} 件"
      plan_year_set_count = count if is_set
    end
    puts ''
    if plan_year_set_count.zero?
      puts '   → plan_year 互換コードの整理を検討可能（全件 null）'
    else
      puts '   → plan_year 互換コードは維持必要（plan_year ありのデータ残存）'
    end
    puts ''
    puts '=== 完了 ==='
  end
end
