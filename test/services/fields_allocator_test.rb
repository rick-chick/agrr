# frozen_string_literal: true

require "test_helper"
require "ostruct"

class FieldsAllocatorTest < ActiveSupport::TestCase
  # テストデータ用の作物オブジェクト作成ヘルパー
  def create_crop(name, area_per_unit)
    OpenStruct.new(name: name, area_per_unit: area_per_unit)
  end
  
  test "allocates area without remainder waste" do
    crops = [
      create_crop("作物A", 30),
      create_crop("作物B", 20),
      create_crop("作物C", 10)
    ]
    
    allocator = FieldsAllocator.new(100, crops)
    result = allocator.allocate
    
    # 合計面積が100㎡になることを確認
    total = result.sum { |r| r[:area] }
    assert_equal 100.0, total, "Total area should be 100㎡"
    
    # 配分を確認（100 ÷ 3 = 33 + 余り1）
    # 優先順位: A(30) > B(20) > C(10)
    # 余り1㎡を作物Aに追加
    assert_equal 34.0, result[0][:area], "作物A should get 34㎡"
    assert_equal 33.0, result[1][:area], "作物B should get 33㎡"
    assert_equal 33.0, result[2][:area], "作物C should get 33㎡"
    
    # 作物の順序を確認
    assert_equal "作物A", result[0][:crop].name
    assert_equal "作物B", result[1][:crop].name
    assert_equal "作物C", result[2][:crop].name
  end
  
  test "handles edge case with single field" do
    crops = [create_crop("作物A", 100)]
    
    allocator = FieldsAllocator.new(50, crops)
    result = allocator.allocate
    
    assert_equal 1, result.count
    assert_equal 50.0, result[0][:area], "Single field should use all area"
  end
  
  test "handles large remainder" do
    crops = (1..7).map { |i| create_crop("作物#{i}", 10) }
    
    allocator = FieldsAllocator.new(100, crops)
    result = allocator.allocate
    
    # 7作物あるが、上限5圃場に制限される
    # 100 ÷ 5 = 20 （余りなし）
    total = result.sum { |r| r[:area] }
    assert_equal 100.0, total
    
    # 5圃場のみ作成される（上限制限）
    assert_equal 5, result.count, "Should be limited to 5 fields"
    
    # 各圃場が20㎡ずつ
    assert_equal 20.0, result[0][:area], "First field should get 20㎡"
    assert_equal 20.0, result[1][:area], "Second field should get 20㎡"
    assert_equal 20.0, result[2][:area], "Third field should get 20㎡"
    assert_equal 20.0, result[3][:area], "Fourth field should get 20㎡"
    assert_equal 20.0, result[4][:area], "Fifth field should get 20㎡"
  end
  
  test "handles area_per_unit nil values" do
    crops = [
      create_crop("作物A", 30),
      create_crop("作物B", nil),
      create_crop("作物C", 20)
    ]
    
    allocator = FieldsAllocator.new(90, crops)
    result = allocator.allocate
    
    total = result.sum { |r| r[:area] }
    assert_equal 90.0, total
    
    # 優先順位: A(30) > C(20) > B(nil=10)
    assert_equal "作物A", result[0][:crop].name
    assert_equal "作物C", result[1][:crop].name
    assert_equal "作物B", result[2][:crop].name
  end
  
  test "handles no remainder case" do
    crops = [
      create_crop("作物A", 30),
      create_crop("作物B", 20),
      create_crop("作物C", 10)
    ]
    
    allocator = FieldsAllocator.new(90, crops)
    result = allocator.allocate
    
    # 90 ÷ 3 = 30 （余りなし）
    total = result.sum { |r| r[:area] }
    assert_equal 90.0, total
    
    # 全ての圃場が等しく30㎡
    assert_equal 30.0, result[0][:area]
    assert_equal 30.0, result[1][:area]
    assert_equal 30.0, result[2][:area]
  end
  
  test "handles small farm size" do
    crops = [
      create_crop("作物A", 10),
      create_crop("作物B", 10)
    ]
    
    allocator = FieldsAllocator.new(30, crops)
    result = allocator.allocate
    
    # 30 ÷ 2 = 15 （余りなし）
    total = result.sum { |r| r[:area] }
    assert_equal 30.0, total
    
    assert_equal 15.0, result[0][:area]
    assert_equal 15.0, result[1][:area]
  end
  
  test "handles area constraint reduces field count" do
    crops = [
      create_crop("作物A", 50),
      create_crop("作物B", 30),
      create_crop("作物C", 20)
    ]
    
    allocator = FieldsAllocator.new(100, crops)
    result = allocator.allocate
    
    # max_area_per_unit = 50
    # 100 ÷ 50 = 2 → 2圃場のみ作成
    # 作物Cは栽培されない
    assert_equal 2, result.count
    
    total = result.sum { |r| r[:area] }
    assert_equal 100.0, total
    
    # 100 ÷ 2 = 50 （余りなし）
    assert_equal 50.0, result[0][:area]
    assert_equal 50.0, result[1][:area]
    
    assert_equal "作物A", result[0][:crop].name
    assert_equal "作物B", result[1][:crop].name
  end
  
  test "field_count method returns correct count" do
    crops = [
      create_crop("作物A", 30),
      create_crop("作物B", 20),
      create_crop("作物C", 10)
    ]
    
    allocator = FieldsAllocator.new(100, crops)
    
    assert_equal 3, allocator.field_count
  end
  
  test "field_count is limited to MAX_FIELDS" do
    # 10作物用意しても、圃場は最大5個まで
    crops = (1..10).map { |i| create_crop("作物#{i}", 10) }
    
    allocator = FieldsAllocator.new(200, crops)
    
    # 上限5圃場に制限される
    assert_equal 5, allocator.field_count
    assert_equal 5, allocator.allocate.count
  end
  
  test "handles floating point total area" do
    crops = [
      create_crop("作物A", 10),
      create_crop("作物B", 10),
      create_crop("作物C", 10)
    ]
    
    allocator = FieldsAllocator.new(33.5, crops)
    result = allocator.allocate
    
    # 33.5 ÷ 3 = 11.166... → floor → 11
    # 余り: 33.5 - 33 = 0.5 → round → 1
    # 配分: 12, 11, 11 (合計34)
    # または: 11, 11, 11 (合計33)
    
    total = result.sum { |r| r[:area] }
    
    # 浮動小数点の許容範囲内
    assert_in_delta 33.0, total, 1.0, "Total should be close to 33.5㎡"
  end
end

