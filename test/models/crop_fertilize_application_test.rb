# frozen_string_literal: true

require "test_helper"

class CropFertilizeApplicationTest < ActiveSupport::TestCase
  setup do
    @crop = create(:crop, :tomato)
    @profile = create(:crop_fertilize_profile, crop: @crop)
  end

  # バリデーションテスト
  test "should validate crop_fertilize_profile_id presence" do
    application = CropFertilizeApplication.new(
      application_type: "basal",
      count: 1,
      total_n: 6.0,
      total_p: 2.0,
      total_k: 3.0
    )
    assert_not application.valid?
    assert_includes application.errors[:crop_fertilize_profile], "を入力してください"
  end

  test "should validate application_type presence" do
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile, application_type: nil)
    assert_not application.valid?
    assert_includes application.errors[:application_type], "を入力してください"
  end

  test "should validate application_type is basal or topdress" do
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile, application_type: "invalid")
    assert_not application.valid?
    assert_includes application.errors[:application_type], "は一覧にありません"
  end

  test "should allow basal application_type" do
    application = build(:crop_fertilize_application, :basal, crop_fertilize_profile: @profile)
    assert application.valid?
  end

  test "should allow topdress application_type" do
    application = build(:crop_fertilize_application, :topdress, crop_fertilize_profile: @profile)
    assert application.valid?
  end

  test "should validate count presence" do
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile, count: nil)
    assert_not application.valid?
    assert_includes application.errors[:count], "を入力してください"
  end

  test "should validate count is greater than 0" do
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile, count: 0)
    assert_not application.valid?
    assert_includes application.errors[:count], "は0より大きい値にしてください"

    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile, count: -1)
    assert_not application.valid?
  end

  test "should validate count is an integer" do
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile, count: 1.5)
    assert_not application.valid?
    assert_includes application.errors[:count], "は整数で入力してください"
  end

  test "should validate total_n presence" do
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile, total_n: nil)
    assert_not application.valid?
    assert_includes application.errors[:total_n], "を入力してください"
  end

  test "should validate total_p presence" do
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile, total_p: nil)
    assert_not application.valid?
    assert_includes application.errors[:total_p], "を入力してください"
  end

  test "should validate total_k presence" do
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile, total_k: nil)
    assert_not application.valid?
    assert_includes application.errors[:total_k], "を入力してください"
  end

  test "should validate total_n is greater than or equal to 0" do
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile, total_n: -1)
    assert_not application.valid?
    assert_includes application.errors[:total_n], "は0以上の値にしてください"
  end

  test "should validate total_p is greater than or equal to 0" do
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile, total_p: -1)
    assert_not application.valid?
    assert_includes application.errors[:total_p], "は0以上の値にしてください"
  end

  test "should validate total_k is greater than or equal to 0" do
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile, total_k: -1)
    assert_not application.valid?
    assert_includes application.errors[:total_k], "は0以上の値にしてください"
  end

  test "should allow zero values for total_n, total_p, total_k" do
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile,
      total_n: 0,
      total_p: 0,
      total_k: 0
    )
    assert application.valid?
  end

  test "should allow nil for per_application fields" do
    application = build(:crop_fertilize_application, :basal, crop_fertilize_profile: @profile,
      per_application_n: nil,
      per_application_p: nil,
      per_application_k: nil
    )
    assert application.valid?
  end

  # カスタムバリデーションテスト
  test "should warn when topdress with multiple count lacks per_application" do
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile,
      application_type: "topdress",
      count: 2,
      per_application_n: nil,
      per_application_p: nil,
      per_application_k: nil
    )
    application.valid?
    assert_includes application.errors[:base], "追肥で複数回の場合、1回あたりの施肥量（per_application）を設定することを推奨します"
  end

  test "should not warn when topdress with single count lacks per_application" do
    application = build(:crop_fertilize_application, :topdress_single, crop_fertilize_profile: @profile)
    assert application.valid?
    assert_not_includes application.errors[:base], "追肥で複数回の場合"
  end

  test "should not warn when topdress with multiple count has per_application" do
    application = build(:crop_fertilize_application, :topdress, crop_fertilize_profile: @profile)
    assert application.valid?
    assert_not_includes application.errors[:base], "追肥で複数回の場合"
  end

  test "should not warn when basal lacks per_application" do
    application = build(:crop_fertilize_application, :basal, crop_fertilize_profile: @profile)
    assert application.valid?
    assert_not_includes application.errors[:base], "追肥で複数回の場合"
  end

  # 関連テスト
  test "should belong to crop_fertilize_profile" do
    application = create(:crop_fertilize_application, crop_fertilize_profile: @profile)
    assert_equal @profile, application.crop_fertilize_profile
  end

  # スコープテスト
  test "basal scope should return only basal applications" do
    basal1 = create(:crop_fertilize_application, :basal, crop_fertilize_profile: @profile)
    basal2 = create(:crop_fertilize_application, :basal, crop_fertilize_profile: create(:crop_fertilize_profile))
    topdress = create(:crop_fertilize_application, :topdress, crop_fertilize_profile: @profile)

    basal_applications = CropFertilizeApplication.basal
    assert_includes basal_applications, basal1
    assert_includes basal_applications, basal2
    assert_not_includes basal_applications, topdress
  end

  test "topdress scope should return only topdress applications" do
    basal = create(:crop_fertilize_application, :basal, crop_fertilize_profile: @profile)
    topdress1 = create(:crop_fertilize_application, :topdress, crop_fertilize_profile: @profile)
    topdress2 = create(:crop_fertilize_application, :topdress, crop_fertilize_profile: create(:crop_fertilize_profile))

    topdress_applications = CropFertilizeApplication.topdress
    assert_not_includes topdress_applications, basal
    assert_includes topdress_applications, topdress1
    assert_includes topdress_applications, topdress2
  end

  # メソッドテスト
  test "application_type_name should return Japanese name for basal" do
    application = create(:crop_fertilize_application, :basal, crop_fertilize_profile: @profile)
    assert_equal "基肥", application.application_type_name
  end

  test "application_type_name should return Japanese name for topdress" do
    application = create(:crop_fertilize_application, :topdress, crop_fertilize_profile: @profile)
    assert_equal "追肥", application.application_type_name
  end

  test "application_type_name should return original value for unknown type" do
    application = CropFertilizeApplication.new(application_type: "unknown")
    assert_equal "unknown", application.application_type_name
  end
end

