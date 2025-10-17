# frozen_string_literal: true

# Region機能デプロイ検証スクリプト
# 本番環境でRegion機能が正しく動作しているか確認

puts "╔═══════════════════════════════════════════════════╗"
puts "║    Region機能デプロイ検証レポート                  ║"
puts "╚═══════════════════════════════════════════════════╝"
puts ""

exit_code = 0

# 1. カラムの存在確認
puts "【1. カラムの存在確認】"
models = [Farm, Field, Crop, InteractionRule]
all_have_region = models.all? { |m| m.column_names.include?('region') }

if all_have_region
  puts "  ✅ すべてのモデルにregionカラムが存在します"
else
  puts "  ❌ 一部のモデルにregionカラムがありません"
  models.each do |model|
    has_region = model.column_names.include?('region')
    puts "     #{model.name}: #{has_region ? '✅' : '❌'}"
  end
  exit_code = 1
end

# 2. インデックスの確認
puts ""
puts "【2. インデックスの確認】"
connection = ActiveRecord::Base.connection
tables = ['farms', 'fields', 'crops', 'interaction_rules']
all_indexed = true

tables.each do |table|
  indexes = connection.indexes(table)
  has_region_index = indexes.any? { |idx| idx.columns.include?('region') }
  
  if has_region_index
    puts "  ✅ #{table}: regionインデックスあり"
  else
    puts "  ⚠️  #{table}: regionインデックスなし"
    all_indexed = false
  end
end

# 3. 日本の参照データの確認
puts ""
puts "【3. 日本の参照データ】"

begin
  jp_farms = Farm.reference.by_region('jp')
  jp_crops = Crop.reference.by_region('jp')
  jp_rules = InteractionRule.reference.by_region('jp')
  jp_fields = Field.by_region('jp')

  puts "  参照農場: #{jp_farms.count}件"
  puts "  参照作物: #{jp_crops.count}件"
  puts "  サンプル圃場: #{jp_fields.count}件"
  puts "  輪作ルール: #{jp_rules.count}件"
  
  # 最低限のデータがあるか確認
  if jp_farms.count == 0
    puts "  ⚠️  参照農場が0件です"
    exit_code = 1
  end
  
  if jp_crops.count == 0
    puts "  ⚠️  参照作物が0件です"
    exit_code = 1
  end
  
rescue => e
  puts "  ❌ エラー: #{e.message}"
  exit_code = 1
end

# 4. region=nilのデータ確認
puts ""
puts "【4. region=nilのデータ確認】"

begin
  nil_farms = Farm.reference.where(region: nil).count
  nil_crops = Crop.reference.where(region: nil).count
  nil_rules = InteractionRule.reference.where(region: nil).count
  nil_fields = Field.where(region: nil).count

  if nil_farms == 0 && nil_crops == 0 && nil_rules == 0
    puts "  ✅ すべての参照データに地域が設定されています"
  else
    puts "  ⚠️  一部の参照データにregion=nilが残っています"
    puts "     参照農場: #{nil_farms}件" if nil_farms > 0
    puts "     参照作物: #{nil_crops}件" if nil_crops > 0
    puts "     輪作ルール: #{nil_rules}件" if nil_rules > 0
    puts "     圃場: #{nil_fields}件" if nil_fields > 0
  end
  
  # nilがある場合は警告（エラーにはしない）
  if nil_farms > 0 || nil_crops > 0 || nil_rules > 0
    puts "  💡 ヒント: bin/rails db:seed を実行して地域情報を設定してください"
  end
  
rescue => e
  puts "  ❌ エラー: #{e.message}"
  exit_code = 1
end

# 5. スコープの動作確認
puts ""
puts "【5. スコープの動作確認】"

begin
  # 各モデルのby_regionスコープをテスト
  Farm.by_region('jp').limit(1).to_a
  Field.by_region('jp').limit(1).to_a
  Crop.by_region('jp').limit(1).to_a
  InteractionRule.by_region('jp').limit(1).to_a
  
  puts "  ✅ by_regionスコープが正常に動作しています"
  
  # referenceスコープとの組み合わせ
  Farm.reference.by_region('jp').limit(1).to_a
  Crop.reference.by_region('jp').limit(1).to_a
  InteractionRule.reference.by_region('jp').limit(1).to_a
  
  puts "  ✅ referenceスコープとの組み合わせも正常です"
  
rescue => e
  puts "  ❌ スコープエラー: #{e.message}"
  puts "     #{e.backtrace.first}"
  exit_code = 1
end

# 6. データサンプルの確認
puts ""
puts "【6. データサンプルの確認】"

begin
  sample_farm = Farm.reference.by_region('jp').first
  if sample_farm
    puts "  サンプル農場: #{sample_farm.name} (region: #{sample_farm.region})"
  else
    puts "  ⚠️  サンプル農場が見つかりません"
  end
  
  sample_crop = Crop.reference.by_region('jp').first
  if sample_crop
    puts "  サンプル作物: #{sample_crop.name} (region: #{sample_crop.region})"
  else
    puts "  ⚠️  サンプル作物が見つかりません"
  end
  
  sample_rule = InteractionRule.reference.by_region('jp').first
  if sample_rule
    puts "  サンプルルール: #{sample_rule.source_group} → #{sample_rule.target_group} (region: #{sample_rule.region})"
  else
    puts "  ⚠️  サンプルルールが見つかりません"
  end
  
rescue => e
  puts "  ❌ エラー: #{e.message}"
  exit_code = 1
end

# 7. パフォーマンステスト
puts ""
puts "【7. パフォーマンステスト】"

begin
  require 'benchmark'
  
  # インデックスが効いているか確認
  time = Benchmark.realtime do
    Farm.by_region('jp').count
    Crop.by_region('jp').count
    InteractionRule.by_region('jp').count
  end
  
  puts "  地域別クエリ実行時間: #{(time * 1000).round(2)}ms"
  
  if time < 0.1
    puts "  ✅ パフォーマンスは良好です"
  elsif time < 0.5
    puts "  ⚠️  パフォーマンスはやや低下しています"
  else
    puts "  ❌ パフォーマンスに問題があります（インデックスを確認してください）"
  end
  
rescue => e
  puts "  ⚠️  パフォーマンステストをスキップ: #{e.message}"
end

# 8. 総括
puts ""
puts "【総括】"

if exit_code == 0
  puts "  🎉 Region機能が正常にデプロイされました！"
  puts ""
  puts "  次のステップ:"
  puts "  1. アメリカ（region: 'us'）の参照データを追加"
  puts "  2. 地域選択UIの実装"
  puts "  3. ユーザーの地域設定機能"
else
  puts "  ⚠️  一部の検証項目で問題があります"
  puts "  詳細は上記のログを確認してください"
end

puts ""
puts "検証完了"

exit exit_code

