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
      count: 1
    )
    assert_not application.valid?
    assert_includes application.errors[:crop_fertilize_profile], "を入力してください"
  end

  # totals計算メソッドのテスト
  test "should calculate total_n from per_application_n and count" do
    application = create(:crop_fertilize_application, :basal, crop_fertilize_profile: @profile)
    assert_equal 6.0, application.total_n  # 6.0 * 1

    application = create(:crop_fertilize_application, :topdress, crop_fertilize_profile: @profile)
    assert_equal 12.0, application.total_n  # 6.0 * 2
  end

  test "should calculate total_p from per_application_p and count" do
    application = create(:crop_fertilize_application, :basal, crop_fertilize_profile: @profile)
    assert_equal 2.0, application.total_p  # 2.0 * 1

    application = create(:crop_fertilize_application, :topdress, crop_fertilize_profile: @profile)
    assert_equal 3.0, application.total_p  # 1.5 * 2
  end

  test "should calculate total_k from per_application_k and count" do
    application = create(:crop_fertilize_application, :basal, crop_fertilize_profile: @profile)
    assert_equal 3.0, application.total_k  # 3.0 * 1

    application = create(:crop_fertilize_application, :topdress, crop_fertilize_profile: @profile)
    assert_equal 9.0, application.total_k  # 4.5 * 2
  end

  test "should return 0 for totals when per_application is nil" do
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile,
      per_application_n: nil,
      per_application_p: nil,
      per_application_k: nil
    )
    assert_equal 0, application.total_n
    assert_equal 0, application.total_p
    assert_equal 0, application.total_k
  end

  test "should not validate per_application_present_for_topdress anymore" do
    # この警告バリデーションは削除された
    application = build(:crop_fertilize_application, crop_fertilize_profile: @profile,
      application_type: "topdress",
      count: 2,
      per_application_n: nil,
      per_application_p: nil,
      per_application_k: nil
    )
    assert application.valid?
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


  test "should allow nil for per_application fields" do
    application = build(:crop_fertilize_application, :basal, crop_fertilize_profile: @profile,
      per_application_n: nil,
      per_application_p: nil,
      per_application_k: nil
    )
    assert application.valid?
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

