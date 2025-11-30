#!/usr/bin/env ruby
# frozen_string_literal: true

# 重複チェックスクリプト
# 同じfarm_id × user_idで複数のplan_yearが存在するか確認

require_relative '../config/environment'

puts "🔍 重複チェックを開始します..."

duplicates = CultivationPlan
  .where(plan_type: 'private')
  .group(:farm_id, :user_id)
  .having('COUNT(*) > 1')
  .count

if duplicates.any?
  puts "❌ 重複データが検出されました:"
  duplicates.each do |(farm_id, user_id), count|
    plans = CultivationPlan.where(plan_type: 'private', farm_id: farm_id, user_id: user_id)
    puts "  - farm_id: #{farm_id}, user_id: #{user_id}, 計画数: #{count}"
    plans.each do |plan|
      puts "    * Plan ID: #{plan.id}, plan_year: #{plan.plan_year}, plan_name: #{plan.plan_name}"
    end
  end
  exit 1
else
  puts "✅ 重複データは検出されませんでした。マイグレーションを実行できます。"
  exit 0
end

