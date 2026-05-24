# frozen_string_literal: true

require "test_helper"

class PesticideTest < ActiveSupport::TestCase
  # バリデーションテスト

  test "should validate crop presence" do
    pest = create(:pest, is_reference: true)
    pesticide = Pesticide.new(name: "テスト農薬", pest: pest)
    assert_not pesticide.valid?
    assert_includes pesticide.errors[:crop], "を入力してください"
  end

  test "should validate pest presence" do
    crop = create(:crop, :reference)
    pesticide = Pesticide.new(name: "テスト農薬", crop: crop)
    assert_not pesticide.valid?
    assert_includes pesticide.errors[:pest], "を入力してください"
  end

  test "should validate name presence" do
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)
    pesticide = Pesticide.new(crop: crop, pest: pest)
    assert_not pesticide.valid?
    assert_includes pesticide.errors[:name], "を入力してください"
  end

  test "should validate is_reference inclusion" do
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)
    pesticide = Pesticide.new(name: "テスト農薬", is_reference: nil, crop: crop, pest: pest)
    assert_not pesticide.valid?
    assert_includes pesticide.errors[:is_reference], "は一覧にありません"
  end

  test "should validate region inclusion" do
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)

    # 有効なregion値
    %w[jp us in].each do |region|
      pesticide = Pesticide.new(name: "テスト農薬", region: region, is_reference: true, crop: crop, pest: pest)
      assert pesticide.valid?, "region '#{region}' should be valid"
    end

    # nilは許可される
    pesticide_nil = Pesticide.new(name: "テスト農薬", region: nil, is_reference: true, crop: crop, pest: pest)
    assert pesticide_nil.valid?, "nil region should be valid"

    # 無効なregion値
    invalid_region = Pesticide.new(name: "テスト農薬", region: "invalid", is_reference: true, crop: crop, pest: pest)
    assert_not invalid_region.valid?
    assert_includes invalid_region.errors[:region], "は一覧にありません"
  end

  test "should validate user presence when is_reference is false" do
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)
    pesticide = Pesticide.new(
      name: "テスト農薬",
      is_reference: false,
      user_id: nil,
      crop: crop,
      pest: pest
    )
    assert_not pesticide.valid?
    assert_includes pesticide.errors[:user], "を入力してください"
  end

  test "should allow nil user_id when is_reference is true" do
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)
    pesticide = Pesticide.new(
      name: "テスト農薬",
      is_reference: true,
      user_id: nil,
      crop: crop,
      pest: pest
    )
    assert pesticide.valid?
  end

  test "should not allow user for reference pesticides" do
    user = create(:user)
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)
    pesticide = Pesticide.new(
      name: "参照農薬",
      is_reference: true,
      user: user,
      crop: crop,
      pest: pest
    )
    pesticide.valid?

    assert_includes pesticide.errors[:user], "は参照データには設定できません"
  end

  test "should allow user_id when is_reference is false" do
    user = create(:user)
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)
    pesticide = Pesticide.new(
      name: "テスト農薬",
      is_reference: false,
      user_id: user.id,
      crop: crop,
      pest: pest
    )
    assert pesticide.valid?
  end

  test "should require user_id when is_reference changes from true to false" do
    user = create(:user)
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)
    pesticide = create(:pesticide, is_reference: true, user_id: nil, crop: crop, pest: pest)

    pesticide.is_reference = false
    assert_not pesticide.valid?
    assert_includes pesticide.errors[:user], "を入力してください"

    pesticide.user_id = user.id
    assert pesticide.valid?
  end

  test "should enforce uniqueness of source_pesticide_id per user" do
    user = create(:user)
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)
    reference = create(:pesticide, is_reference: true, crop: crop, pest: pest)

    create(:pesticide,
           is_reference: false,
           user: user,
           crop: crop,
           pest: pest,
           source_pesticide_id: reference.id)

    duplicated = build(:pesticide,
                       is_reference: false,
                       user: user,
                       crop: crop,
                       pest: pest,
                       source_pesticide_id: reference.id)
    assert_not duplicated.valid?
    assert_includes duplicated.errors[:source_pesticide_id], "はすでに存在します"

    another_user = create(:user)
    other = build(:pesticide,
                  is_reference: false,
                  user: another_user,
                  crop: crop,
                  pest: pest,
                  source_pesticide_id: reference.id)
    assert other.valid?
  end

  # 関連テスト
  test "should belong to user" do
    user = create(:user)
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)
    pesticide = create(:pesticide, user: user, crop: crop, pest: pest, is_reference: false)

    assert_equal user.id, pesticide.user_id
    assert_equal user, pesticide.user
  end

  test "should allow nil user for reference pesticides" do
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)
    pesticide = create(:pesticide, user_id: nil, crop: crop, pest: pest, is_reference: true)

    assert_nil pesticide.user_id
    assert_nil pesticide.user
  end

  test "user should have many pesticides" do
    user = create(:user)
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)
    pesticide1 = create(:pesticide, user: user, crop: crop, pest: pest, is_reference: false)
    pesticide2 = create(:pesticide, user: user, crop: crop, pest: pest, is_reference: false)

    assert_equal 2, user.pesticides.count
    assert_includes user.pesticides, pesticide1
    assert_includes user.pesticides, pesticide2
  end

  test "user pesticides should be destroyed when user is destroyed" do
    user = create(:user)
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)
    pesticide = create(:pesticide, user: user, crop: crop, pest: pest, is_reference: false)
    pesticide_id = pesticide.id

    user.destroy

    assert_not Pesticide.exists?(pesticide_id)
  end

  test "should filter pesticides by is_reference and user_id combination" do
    user1 = create(:user)
    user2 = create(:user)
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)

    ref_pesticide = create(:pesticide, is_reference: true, user_id: nil, crop: crop, pest: pest)
    user1_pesticide = create(:pesticide, is_reference: false, user: user1, crop: crop, pest: pest)
    user2_pesticide = create(:pesticide, is_reference: false, user: user2, crop: crop, pest: pest)

    # 一般ユーザーの視点
    visible_pesticides = Pesticide.where("is_reference = ? OR user_id = ?", true, user1.id)

    assert_includes visible_pesticides, ref_pesticide
    assert_includes visible_pesticides, user1_pesticide
    assert_not_includes visible_pesticides, user2_pesticide
  end

  test "should have one pesticide_usage_constraint" do
    pesticide = create(:pesticide, :with_usage_constraint)
    assert_not_nil pesticide.pesticide_usage_constraint
    assert_equal 5.0, pesticide.pesticide_usage_constraint.min_temperature
  end

  test "should have one pesticide_application_detail" do
    pesticide = create(:pesticide, :with_application_detail)
    assert_not_nil pesticide.pesticide_application_detail
    assert_equal "1000倍", pesticide.pesticide_application_detail.dilution_ratio
  end

  test "should destroy related records when pesticide is destroyed" do
    pesticide = create(:pesticide, :complete)
    usage_constraint_id = pesticide.pesticide_usage_constraint.id
    application_detail_id = pesticide.pesticide_application_detail.id

    pesticide.destroy

    assert_not PesticideUsageConstraint.exists?(usage_constraint_id)
    assert_not PesticideApplicationDetail.exists?(application_detail_id)
  end


  # スコープテスト
  test "reference scope should return reference pesticides" do
    user = create(:user)
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)
    reference_pesticide = create(:pesticide, is_reference: true, crop: crop, pest: pest)
    user_pesticide = create(:pesticide, is_reference: false, user: user, crop: crop, pest: pest)

    reference_pesticides = Pesticide.reference

    assert_includes reference_pesticides, reference_pesticide
    assert_not_includes reference_pesticides, user_pesticide
  end

  test "user_owned scope should return only user-owned pesticides" do
    user = create(:user)
    crop = create(:crop, :reference)
    pest = create(:pest, is_reference: true)
    reference_pesticide = create(:pesticide, is_reference: true, user_id: nil, crop: crop, pest: pest)
    user_pesticide = create(:pesticide, is_reference: false, user: user, crop: crop, pest: pest)

    user_owned_pesticides = Pesticide.user_owned

    assert_includes user_owned_pesticides, user_pesticide
    assert_not_includes user_owned_pesticides, reference_pesticide
  end

  test "recent scope should order by created_at desc" do
    pesticide1 = create(:pesticide, created_at: 2.days.ago)
    pesticide2 = create(:pesticide, created_at: 1.day.ago)
    pesticide3 = create(:pesticide, created_at: Time.current)

    recent = Pesticide.recent.limit(3)

    assert_equal pesticide3.id, recent.first.id
    assert_equal pesticide2.id, recent.second.id
    assert_equal pesticide1.id, recent.third.id
  end

  # _destroyフラグのテスト
  test "should destroy usage_constraint with nested attributes _destroy flag" do
    pesticide = create(:pesticide, :with_usage_constraint)
    constraint_id = pesticide.pesticide_usage_constraint.id

    pesticide.update(
      pesticide_usage_constraint_attributes: {
        id: constraint_id,
        _destroy: "1"
      }
    )

    assert_not PesticideUsageConstraint.exists?(constraint_id)
  end

  test "should destroy application_detail with nested attributes _destroy flag" do
    pesticide = create(:pesticide, :with_application_detail)
    detail_id = pesticide.pesticide_application_detail.id

    pesticide.update(
      pesticide_application_detail_attributes: {
        id: detail_id,
        _destroy: "1"
      }
    )

    assert_not PesticideApplicationDetail.exists?(detail_id)
  end

  # Pesticide経由でのバリデーションエラー検出
  test "should validate usage_constraint temperature constraints through pesticide" do
    pesticide = build(:pesticide)
    pesticide.build_pesticide_usage_constraint(
      min_temperature: 40.0,
      max_temperature: 35.0
    )

    assert_not pesticide.valid?
    assert_includes pesticide.pesticide_usage_constraint.errors[:min_temperature],
                    "must be less than or equal to max_temperature"
  end

  test "should validate application_detail amount and unit consistency through pesticide" do
    pesticide = build(:pesticide)
    pesticide.build_pesticide_application_detail(
      amount_per_m2: 0.1,
      amount_unit: nil
    )

    assert_not pesticide.valid?
    assert_includes pesticide.pesticide_application_detail.errors[:amount_per_m2],
                    "requires amount_unit"
  end
end
