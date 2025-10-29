#!/usr/bin/env ruby
# frozen_string_literal: true

# 最適化時とGDD推移表示時で使う気象データが同じか確認するスクリプト

require_relative '../config/environment'

def compare_weather_data(field_cultivation_id)
  field_cultivation = FieldCultivation.find(field_cultivation_id)
  cultivation_plan = field_cultivation.cultivation_plan
  farm = cultivation_plan.farm
  
  puts "=" * 80
  puts "気象データ比較: FieldCultivation ##{field_cultivation_id}"
  puts "=" * 80
  puts
  
  # 1. 最適化時に使った気象データを取得
  puts "【1. 最適化時に使った気象データ】"
  puts "-" * 80
  
  if cultivation_plan.predicted_weather_data.present?
    optimization_weather = cultivation_plan.predicted_weather_data
    puts "✅ CultivationPlan##{cultivation_plan.id} に保存された気象データが存在します"
    puts "   生成日時: #{optimization_weather['generated_at']}"
    puts "   予測開始日: #{optimization_weather['prediction_start_date']}"
    puts "   予測終了日: #{optimization_weather['target_end_date'] || optimization_weather['prediction_end_date']}"
    puts "   データ件数: #{optimization_weather['data']&.count || 'N/A'}"
    
    # 栽培期間内のデータを抽出
    cultivation_start = field_cultivation.start_date
    cultivation_end = field_cultivation.completion_date
    
    optimization_data_in_period = optimization_weather['data']&.select do |datum|
      datum_date = Date.parse(datum['date'] || datum['time'])
      datum_date.between?(cultivation_start, cultivation_end)
    end || []
    
    puts "   栽培期間内のデータ件数: #{optimization_data_in_period.count} (#{cultivation_start} 〜 #{cultivation_end})"
    
    if optimization_data_in_period.any?
      sample_day = optimization_data_in_period.first
      puts "   サンプル（最初の日）:"
      puts "     日付: #{sample_day['date'] || sample_day['time']}"
      puts "     最高気温: #{sample_day['temperature_max'] || sample_day['temperature_2m_max']}"
      puts "     最低気温: #{sample_day['temperature_min'] || sample_day['temperature_2m_min']}"
      puts "     平均気温: #{sample_day['temperature_mean'] || sample_day['temperature_2m_mean']}"
    end
  else
    puts "❌ CultivationPlan##{cultivation_plan.id} に保存された気象データがありません"
    optimization_weather = nil
    optimization_data_in_period = []
  end
  
  puts
  puts "【2. GDD推移表示時に使う気象データ】"
  puts "-" * 80
  
  # GDD推移表示時のロジックを再現
  if cultivation_plan.predicted_weather_data.present?
    saved_data = cultivation_plan.predicted_weather_data
    
    # 古い保存形式のチェック
    if saved_data['data'].is_a?(Hash) && saved_data['data']['data'].is_a?(Array)
      weather_data_for_cli = saved_data['data']
      puts "⚠️  古いネスト構造形式を検出（内部データを抽出）"
    else
      weather_data_for_cli = saved_data
    end
    
    puts "✅ 最適化時に保存した気象データを再利用します"
    puts "   データ件数: #{weather_data_for_cli['data']&.count || 'N/A'}"
    
    # 栽培期間内のデータを抽出
    gdd_data_in_period = weather_data_for_cli['data']&.select do |datum|
      datum_date = Date.parse(datum['time'] || datum['date'])
      datum_date.between?(cultivation_start, cultivation_end)
    end || []
    
    puts "   栽培期間内のデータ件数: #{gdd_data_in_period.count}"
    
    if gdd_data_in_period.any?
      sample_day = gdd_data_in_period.first
      puts "   サンプル（最初の日）:"
      puts "     日付: #{sample_day['time'] || sample_day['date']}"
      puts "     最高気温: #{sample_day['temperature_2m_max']}"
      puts "     最低気温: #{sample_day['temperature_2m_min']}"
      puts "     平均気温: #{sample_day['temperature_2m_mean']}"
    end
  else
    puts "❌ 保存された気象データがないため、get_weather_data_for_period を使用（フォールバック）"
    gdd_data_in_period = []
  end
  
  puts
  puts "【3. 比較結果】"
  puts "-" * 80
  
  if optimization_data_in_period.empty? && gdd_data_in_period.empty?
    puts "⚠️  両方ともデータがありません"
  elsif optimization_data_in_period.empty?
    puts "❌ 最適化時のデータがありません"
  elsif gdd_data_in_period.empty?
    puts "❌ GDD推移表示時のデータがありません"
  else
    # データ件数を比較
    if optimization_data_in_period.count == gdd_data_in_period.count
      puts "✅ データ件数: 一致 (#{optimization_data_in_period.count}件)"
    else
      puts "⚠️  データ件数: 不一致 (最適化時: #{optimization_data_in_period.count}, GDD推移: #{gdd_data_in_period.count})"
    end
    
    # 最初の日のデータを比較
    opt_first = optimization_data_in_period.first
    gdd_first = gdd_data_in_period.first
    
    opt_date = Date.parse(opt_first['date'] || opt_first['time'])
    gdd_date = Date.parse(gdd_first['time'] || gdd_first['date'])
    
    if opt_date == gdd_date
      puts "✅ 最初の日付: 一致 (#{opt_date})"
    else
      puts "⚠️  最初の日付: 不一致 (最適化時: #{opt_date}, GDD推移: #{gdd_date})"
    end
    
    # 気温データを比較（キー名が異なる場合があるため正規化）
    opt_temp_max = opt_first['temperature_max'] || opt_first['temperature_2m_max']
    opt_temp_min = opt_first['temperature_min'] || opt_first['temperature_2m_min']
    opt_temp_mean = opt_first['temperature_mean'] || opt_first['temperature_2m_mean']
    
    gdd_temp_max = gdd_first['temperature_2m_max']
    gdd_temp_min = gdd_first['temperature_2m_min']
    gdd_temp_mean = gdd_first['temperature_2m_mean']
    
    temp_match = (opt_temp_max == gdd_temp_max) && 
                 (opt_temp_min == gdd_temp_min) && 
                 (opt_temp_mean == gdd_temp_mean)
    
    if temp_match
      puts "✅ 気温データ（最初の日）: 一致"
      puts "   最高気温: #{opt_temp_max}, 最低気温: #{opt_temp_min}, 平均気温: #{opt_temp_mean}"
    else
      puts "⚠️  気温データ（最初の日）: 不一致"
      puts "   最適化時: 最高=#{opt_temp_max}, 最低=#{opt_temp_min}, 平均=#{opt_temp_mean}"
      puts "   GDD推移: 最高=#{gdd_temp_max}, 最低=#{gdd_temp_min}, 平均=#{gdd_temp_mean}"
    end
    
    # 全ての日のデータを比較
    puts
    puts "【4. 詳細比較（最初の5日）】"
    puts "-" * 80
    
    (0..[4, optimization_data_in_period.count - 1, gdd_data_in_period.count - 1].min).each do |i|
      opt_day = optimization_data_in_period[i]
      gdd_day = gdd_data_in_period[i]
      
      opt_date = Date.parse(opt_day['date'] || opt_day['time'])
      gdd_date = Date.parse(gdd_day['time'] || gdd_day['date'])
      
      opt_temp_mean = opt_day['temperature_mean'] || opt_day['temperature_2m_mean']
      gdd_temp_mean = gdd_day['temperature_2m_mean']
      
      match_marker = (opt_date == gdd_date && opt_temp_mean == gdd_temp_mean) ? "✅" : "⚠️ "
      
      puts "#{match_marker} 日#{i + 1}: #{opt_date} | 最適化時平均気温=#{opt_temp_mean}, GDD推移平均気温=#{gdd_temp_mean}"
    end
  end
  
  puts
  puts "=" * 80
  puts "【結論】"
  puts "-" * 80
  
  if optimization_data_in_period.any? && gdd_data_in_period.any?
    if optimization_data_in_period.count == gdd_data_in_period.count
      opt_first_mean = optimization_data_in_period.first['temperature_mean'] || optimization_data_in_period.first['temperature_2m_mean']
      gdd_first_mean = gdd_data_in_period.first['temperature_2m_mean']
      
      if opt_first_mean == gdd_first_mean
        puts "✅ 同じ気象データを使用しています"
        puts "   - 最適化時に保存された predicted_weather_data を再利用"
        puts "   - データ件数・気温値ともに一致"
      else
        puts "⚠️  データソースは同じですが、値が異なる可能性があります"
        puts "   - データフォーマットの違いを確認してください"
      end
    else
      puts "⚠️  データ件数が異なります"
    end
  else
    puts "⚠️  データが不十分です。最適化が実行されているか確認してください"
  end
  
  puts "=" * 80
end

# メイン処理
if ARGV.empty?
  puts "使い方: ruby scripts/compare_weather_data.rb <field_cultivation_id>"
  puts
  puts "例: ruby scripts/compare_weather_data.rb 1"
  exit 1
end

field_cultivation_id = ARGV[0].to_i
compare_weather_data(field_cultivation_id)


