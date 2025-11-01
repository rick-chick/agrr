# frozen_string_literal: true

require "test_helper"

class FertilizeTest < ActiveSupport::TestCase
  test "should validate name presence" do
    fertilize = Fertilize.new
    fertilize.valid?
    assert_includes fertilize.errors[:name], "を入力してください"
  end

  test "should validate name uniqueness" do
    create(:fertilize, name: "尿素")
    fertilize = Fertilize.new(name: "尿素")
    fertilize.valid?
    assert_includes fertilize.errors[:name], "はすでに存在します"
  end

  test "should validate n is greater than or equal to 0" do
    fertilize = build(:fertilize, n: -1)
    fertilize.valid?
    assert_includes fertilize.errors[:n], "は0以上の値にしてください"
  end

  test "should validate p is greater than or equal to 0" do
    fertilize = build(:fertilize, p: -1)
    fertilize.valid?
    assert_includes fertilize.errors[:p], "は0以上の値にしてください"
  end

  test "should validate k is greater than or equal to 0" do
    fertilize = build(:fertilize, k: -1)
    fertilize.valid?
    assert_includes fertilize.errors[:k], "は0以上の値にしてください"
  end

  test "should allow nil for n, p, k" do
    fertilize = build(:fertilize, n: nil, p: nil, k: nil)
    assert fertilize.valid?
  end

  test "has_nutrient? should return true when nutrient is present and > 0" do
    fertilize = create(:fertilize, :urea)
    assert fertilize.has_nutrient?(:n)
    assert_not fertilize.has_nutrient?(:p)
    assert_not fertilize.has_nutrient?(:k)
  end

  test "has_nutrient? should return false when nutrient is nil or 0" do
    fertilize = create(:fertilize, n: 0, p: nil)
    assert_not fertilize.has_nutrient?(:n)
    assert_not fertilize.has_nutrient?(:p)
  end

  test "npk_summary should return formatted string" do
    fertilize = create(:fertilize, n: 20, p: 10, k: 5)
    assert_equal "20-10-5", fertilize.npk_summary
  end

  test "npk_summary should handle nil values" do
    fertilize = create(:fertilize, n: 20, p: nil, k: 10)
    assert_equal "20-10", fertilize.npk_summary
  end

  test "reference scope should return only reference fertilizes" do
    create(:fertilize, is_reference: true)
    create(:fertilize, is_reference: false)
    
    assert_equal 1, Fertilize.reference.count
  end
end

