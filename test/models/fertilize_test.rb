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

  test "should allow updating with same name (exclude self)" do
    fertilize = create(:fertilize, name: "尿素", n: 46.0)
    fertilize.name = "尿素"  # 同じ名前で更新
    assert fertilize.valid?, "編集時は同じ名前で更新できる必要がある"
    assert fertilize.save
  end

  test "should not allow updating to existing other name" do
    create(:fertilize, name: "リン酸一安")
    fertilize = create(:fertilize, name: "尿素", n: 46.0)
    fertilize.name = "リン酸一安"  # 別の既存の名前で更新
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
    create(:fertilize, is_reference: true, user_id: nil)
    user = create(:user)
    create(:fertilize, :user_owned, user: user)
    
    assert_equal 1, Fertilize.reference.count
  end

  # ========== user_id バリデーションのテスト ==========
  
  test "should validate user presence when is_reference is false" do
    fertilize = Fertilize.new(
      name: "テスト肥料",
      is_reference: false,
      user_id: nil
    )
    assert_not fertilize.valid?
    assert_includes fertilize.errors[:user], "を入力してください"
  end

  test "should allow nil user_id when is_reference is true" do
    fertilize = Fertilize.new(
      name: "テスト肥料",
      is_reference: true,
      user_id: nil
    )
    assert fertilize.valid?
  end

  test "should allow user_id when is_reference is false" do
    user = create(:user)
    fertilize = Fertilize.new(
      name: "テスト肥料",
      is_reference: false,
      user_id: user.id
    )
    assert fertilize.valid?
  end

  test "should require user_id when is_reference changes from true to false" do
    user = create(:user)
    fertilize = create(:fertilize, is_reference: true, user_id: nil)
    
    fertilize.is_reference = false
    assert_not fertilize.valid?
    assert_includes fertilize.errors[:user], "を入力してください"
    
    fertilize.user_id = user.id
    assert fertilize.valid?
  end

  test "should belong to user" do
    user = create(:user)
    fertilize = create(:fertilize, :user_owned, user: user)
    
    assert_equal user.id, fertilize.user_id
    assert_equal user, fertilize.user
  end

  test "should allow nil user for reference fertilizes" do
    fertilize = create(:fertilize, is_reference: true, user_id: nil)
    
    assert_nil fertilize.user_id
    assert_nil fertilize.user
  end

  test "user should have many fertilizes" do
    user = create(:user)
    fertilize1 = create(:fertilize, :user_owned, user: user)
    fertilize2 = create(:fertilize, :user_owned, user: user)
    
    assert_includes user.fertilizes, fertilize1
    assert_includes user.fertilizes, fertilize2
    assert_equal 2, user.fertilizes.count
  end

  test "should enforce uniqueness of source_fertilize_id per user" do
    user = create(:user)
    reference = create(:fertilize, is_reference: true)

    create(:fertilize, :user_owned, user: user, source_fertilize_id: reference.id)

    duplicated = build(:fertilize, :user_owned, user: user, source_fertilize_id: reference.id)
    assert_not duplicated.valid?
    assert_includes duplicated.errors[:source_fertilize_id], "はすでに存在します"

    another_user = create(:user)
    other = build(:fertilize, :user_owned, user: another_user, source_fertilize_id: reference.id)
    assert other.valid?
  end

  test "should filter fertilizes by is_reference and user_id combination" do
    user1 = create(:user)
    user2 = create(:user)
    
    ref_fertilize = create(:fertilize, is_reference: true, user_id: nil)
    user1_fertilize = create(:fertilize, :user_owned, user: user1)
    user2_fertilize = create(:fertilize, :user_owned, user: user2)
    
    # 一般ユーザーの視点（自身の肥料のみ）
    visible_fertilizes = Fertilize.where(user_id: user1.id, is_reference: false)
    
    assert_includes visible_fertilizes, user1_fertilize
    assert_not_includes visible_fertilizes, ref_fertilize
    assert_not_includes visible_fertilizes, user2_fertilize
    
    # 管理者の視点（参照肥料または自身の肥料）
    admin_user = create(:user, admin: true)
    admin_visible_fertilizes = Fertilize.where("is_reference = ? OR user_id = ?", true, admin_user.id)
    
    assert_includes admin_visible_fertilizes, ref_fertilize
  end

  test "user_owned scope should return only user owned fertilizes" do
    create(:fertilize, is_reference: true, user_id: nil)
    user_fertilize = create(:fertilize, :user_owned)
    
    assert_equal 1, Fertilize.user_owned.count
    assert_includes Fertilize.user_owned, user_fertilize
  end
end

