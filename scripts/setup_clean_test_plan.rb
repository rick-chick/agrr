#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'config/environment'

# テスト用の計画を作成
farm = Farm.first
cp = CultivationPlan.create!(
  farm: farm,
  user: farm.user,
  planning_start_date: Date.new(2025, 10, 19),
  planning_end_date: Date.new(2026, 12, 31),
  status: :completed,
  total_profit: 20000.0,
  total_area: 300.0
)

# 3つの圃場を作成
field1 = CultivationPlanField.create!(cultivation_plan: cp, name: 'テスト1', area: 150.0, daily_fixed_cost: 10.0)
field2 = CultivationPlanField.create!(cultivation_plan: cp, name: 'テスト2', area: 150.0, daily_fixed_cost: 10.0)
field3 = CultivationPlanField.create!(cultivation_plan: cp, name: 'テスト3', area: 150.0, daily_fixed_cost: 10.0)

# 作物を作成
crop = Crop.find(7)  # ほうれん草
plan_crop = CultivationPlanCrop.create!(cultivation_plan: cp, crop: crop, name: crop.name, variety: crop.variety)

# 各圃場に1つずつ栽培を作成（重複しない日付）
fc1 = FieldCultivation.create!(
  cultivation_plan: cp,
  cultivation_plan_field: field1,
  cultivation_plan_crop: plan_crop,
  start_date: Date.new(2026, 3, 1),
  completion_date: Date.new(2026, 4, 30),
  cultivation_days: 61,
  area: 150.0,
  estimated_cost: 610.0,
  optimization_result: {revenue: 10000.0, profit: 9390.0, accumulated_gdd: 500.0}
)

fc2 = FieldCultivation.create!(
  cultivation_plan: cp,
  cultivation_plan_field: field2,
  cultivation_plan_crop: plan_crop,
  start_date: Date.new(2026, 6, 1),
  completion_date: Date.new(2026, 7, 30),
  cultivation_days: 60,
  area: 150.0,
  estimated_cost: 600.0,
  optimization_result: {revenue: 10000.0, profit: 9400.0, accumulated_gdd: 500.0}
)

fc3 = FieldCultivation.create!(
  cultivation_plan: cp,
  cultivation_plan_field: field3,
  cultivation_plan_crop: plan_crop,
  start_date: Date.new(2026, 9, 1),
  completion_date: Date.new(2026, 10, 30),
  cultivation_days: 60,
  area: 150.0,
  estimated_cost: 600.0,
  optimization_result: {revenue: 10000.0, profit: 9400.0, accumulated_gdd: 500.0}
)

puts "✅ テスト計画を作成しました"
puts "  Plan ID: #{cp.id}"
puts "  圃場数: #{cp.cultivation_plan_fields.count}"
puts "  栽培数: #{cp.field_cultivations.count}"
puts ""
puts "📋 データ:"
puts "  - FC #{fc1.id}: #{field1.name} (field_#{field1.id}), 2026-03-01 - 2026-04-30"
puts "  - FC #{fc2.id}: #{field2.name} (field_#{field2.id}), 2026-06-01 - 2026-07-30"
puts "  - FC #{fc3.id}: #{field3.name} (field_#{field3.id}), 2026-09-01 - 2026-10-30"
puts ""
puts "🌐 テストURL: http://localhost:3000/public_plans/results?plan_id=#{cp.id}"

