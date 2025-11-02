# frozen_string_literal: true

require "test_helper"

class PesticideTest < ActiveSupport::TestCase
  setup do
    @crop = create(:crop, is_reference: true)
    @pest = create(:pest, is_reference: true)
    @pesticide_data = {
      "pesticide_id" => "acetamiprid",
      "name" => "アセタミプリド",
      "active_ingredient" => "アセタミプリド",
      "description" => "浸透性殺虫剤として広く使用される",
      "usage_constraints" => {
        "min_temperature" => 5.0,
        "max_temperature" => 35.0,
        "max_wind_speed_m_s" => 3.0,
        "max_application_count" => 3,
        "harvest_interval_days" => 1,
        "other_constraints" => nil
      },
      "application_details" => {
        "dilution_ratio" => "1000倍",
        "amount_per_m2" => 0.1,
        "amount_unit" => "ml",
        "application_method" => "散布"
      }
    }
  end

  # バリデーションテスト
  test "should validate pesticide_id presence" do
    pesticide = Pesticide.new(name: "テスト農薬")
    assert_not pesticide.valid?
    assert_includes pesticide.errors[:pesticide_id], "を入力してください"
  end

  test "should validate pesticide_id uniqueness with scope crop_id and pest_id" do
    crop1 = create(:crop, is_reference: true)
    crop2 = create(:crop, is_reference: true)
    pest1 = create(:pest, is_reference: true)
    pest2 = create(:pest, is_reference: true)
    
    create(:pesticide, pesticide_id: "test_pesticide", crop: crop1, pest: pest1)
    
    # 同じpesticide_idでも、crop_idまたはpest_idが異なれば有効
    pesticide2 = Pesticide.new(pesticide_id: "test_pesticide", name: "テスト農薬2", crop: crop2, pest: pest1, is_reference: true)
    assert pesticide2.valid?
    
    pesticide3 = Pesticide.new(pesticide_id: "test_pesticide", name: "テスト農薬3", crop: crop1, pest: pest2, is_reference: true)
    assert pesticide3.valid?
    
    # 同じpesticide_id、crop_id、pest_idの組み合わせは無効
    pesticide4 = Pesticide.new(pesticide_id: "test_pesticide", name: "テスト農薬4", crop: crop1, pest: pest1, is_reference: true)
    assert_not pesticide4.valid?
    assert_includes pesticide4.errors[:pesticide_id], "はすでに存在します"
  end

  test "should validate crop presence" do
    pest = create(:pest, is_reference: true)
    pesticide = Pesticide.new(pesticide_id: "test_pesticide", name: "テスト農薬", pest: pest)
    assert_not pesticide.valid?
    assert_includes pesticide.errors[:crop], "を入力してください"
  end

  test "should validate pest presence" do
    crop = create(:crop, is_reference: true)
    pesticide = Pesticide.new(pesticide_id: "test_pesticide", name: "テスト農薬", crop: crop)
    assert_not pesticide.valid?
    assert_includes pesticide.errors[:pest], "を入力してください"
  end

  test "should validate name presence" do
    pesticide = Pesticide.new(pesticide_id: "test_pesticide")
    assert_not pesticide.valid?
    assert_includes pesticide.errors[:name], "を入力してください"
  end

  test "should validate is_reference inclusion" do
    pesticide = Pesticide.new(pesticide_id: "test_pesticide", name: "テスト農薬", is_reference: nil)
    assert_not pesticide.valid?
    assert_includes pesticide.errors[:is_reference], "は一覧にありません"
  end

  test "should validate user presence when is_reference is false" do
    crop = create(:crop, is_reference: true)
    pest = create(:pest, is_reference: true)
    pesticide = Pesticide.new(
      pesticide_id: "test_pesticide",
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
    crop = create(:crop, is_reference: true)
    pest = create(:pest, is_reference: true)
    pesticide = Pesticide.new(
      pesticide_id: "test_pesticide",
      name: "テスト農薬",
      is_reference: true,
      user_id: nil,
      crop: crop,
      pest: pest
    )
    assert pesticide.valid?
  end

  test "should allow user_id when is_reference is false" do
    user = create(:user)
    crop = create(:crop, is_reference: true)
    pest = create(:pest, is_reference: true)
    pesticide = Pesticide.new(
      pesticide_id: "test_pesticide",
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
    crop = create(:crop, is_reference: true)
    pest = create(:pest, is_reference: true)
    pesticide = create(:pesticide, is_reference: true, user_id: nil, crop: crop, pest: pest)
    
    pesticide.is_reference = false
    assert_not pesticide.valid?
    assert_includes pesticide.errors[:user], "を入力してください"
    
    pesticide.user_id = user.id
    assert pesticide.valid?
  end

  # 関連テスト
  test "should belong to user" do
    user = create(:user)
    crop = create(:crop, is_reference: true)
    pest = create(:pest, is_reference: true)
    pesticide = create(:pesticide, user: user, crop: crop, pest: pest, is_reference: false)
    
    assert_equal user.id, pesticide.user_id
    assert_equal user, pesticide.user
  end

  test "should allow nil user for reference pesticides" do
    crop = create(:crop, is_reference: true)
    pest = create(:pest, is_reference: true)
    pesticide = create(:pesticide, user_id: nil, crop: crop, pest: pest, is_reference: true)
    
    assert_nil pesticide.user_id
    assert_nil pesticide.user
  end

  test "user should have many pesticides" do
    user = create(:user)
    crop = create(:crop, is_reference: true)
    pest = create(:pest, is_reference: true)
    pesticide1 = create(:pesticide, user: user, crop: crop, pest: pest, is_reference: false)
    pesticide2 = create(:pesticide, user: user, crop: crop, pest: pest, is_reference: false)
    
    assert_equal 2, user.pesticides.count
    assert_includes user.pesticides, pesticide1
    assert_includes user.pesticides, pesticide2
  end

  test "user pesticides should be destroyed when user is destroyed" do
    user = create(:user)
    crop = create(:crop, is_reference: true)
    pest = create(:pest, is_reference: true)
    pesticide = create(:pesticide, user: user, crop: crop, pest: pest, is_reference: false)
    pesticide_id = pesticide.id
    
    user.destroy
    
    assert_not Pesticide.exists?(pesticide_id)
  end

  test "should filter pesticides by is_reference and user_id combination" do
    user1 = create(:user)
    user2 = create(:user)
    crop = create(:crop, is_reference: true)
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

  # from_agrr_output テスト（agrr CLI出力形式から作成）
  test "should create pesticide from agrr output" do
    pesticide = Pesticide.from_agrr_output(
      pesticide_data: @pesticide_data,
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    )

    assert pesticide.persisted?
    assert_equal "acetamiprid", pesticide.pesticide_id
    assert_equal "アセタミプリド", pesticide.name
    assert_equal "アセタミプリド", pesticide.active_ingredient
    assert_equal "浸透性殺虫剤として広く使用される", pesticide.description
    assert_equal true, pesticide.is_reference
  end

  test "from_agrr_output should create usage_constraints" do
    pesticide = Pesticide.from_agrr_output(
      pesticide_data: @pesticide_data,
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    )

    assert_not_nil pesticide.pesticide_usage_constraint
    assert_equal 5.0, pesticide.pesticide_usage_constraint.min_temperature
    assert_equal 35.0, pesticide.pesticide_usage_constraint.max_temperature
    assert_equal 3.0, pesticide.pesticide_usage_constraint.max_wind_speed_m_s
    assert_equal 3, pesticide.pesticide_usage_constraint.max_application_count
    assert_equal 1, pesticide.pesticide_usage_constraint.harvest_interval_days
  end

  test "from_agrr_output should create application_details" do
    pesticide = Pesticide.from_agrr_output(
      pesticide_data: @pesticide_data,
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    )

    assert_not_nil pesticide.pesticide_application_detail
    assert_equal "1000倍", pesticide.pesticide_application_detail.dilution_ratio
    assert_equal 0.1, pesticide.pesticide_application_detail.amount_per_m2
    assert_equal "ml", pesticide.pesticide_application_detail.amount_unit
    assert_equal "散布", pesticide.pesticide_application_detail.application_method
  end

  test "from_agrr_output should handle nil usage_constraints" do
    pesticide_data_without_constraints = @pesticide_data.dup
    pesticide_data_without_constraints.delete("usage_constraints")

    pesticide = Pesticide.from_agrr_output(
      pesticide_data: pesticide_data_without_constraints,
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    )

    assert_nil pesticide.pesticide_usage_constraint
  end

  test "from_agrr_output should keep existing usage_constraints when nil is passed" do
    existing_pesticide = create(:pesticide, pesticide_id: "acetamiprid", crop: @crop, pest: @pest)
    create(:pesticide_usage_constraint, pesticide: existing_pesticide)
    constraint_id = existing_pesticide.reload.pesticide_usage_constraint.id
    original_min_temp = existing_pesticide.pesticide_usage_constraint.min_temperature

    pesticide_data_without_constraints = @pesticide_data.dup
    pesticide_data_without_constraints["usage_constraints"] = nil

    pesticide = Pesticide.from_agrr_output(
      pesticide_data: pesticide_data_without_constraints,
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    )

    # 既存のusage_constraintsは残る（実装によるが、現状は削除されない）
    assert_not_nil pesticide.pesticide_usage_constraint
    assert_equal constraint_id, pesticide.pesticide_usage_constraint.id
    assert_equal original_min_temp, pesticide.pesticide_usage_constraint.min_temperature
  end

  test "from_agrr_output should keep existing application_details when nil is passed" do
    existing_pesticide = create(:pesticide, pesticide_id: "acetamiprid", crop: @crop, pest: @pest)
    create(:pesticide_application_detail, pesticide: existing_pesticide)
    detail_id = existing_pesticide.reload.pesticide_application_detail.id
    original_ratio = existing_pesticide.pesticide_application_detail.dilution_ratio

    pesticide_data_without_details = @pesticide_data.dup
    pesticide_data_without_details["application_details"] = nil

    pesticide = Pesticide.from_agrr_output(
      pesticide_data: pesticide_data_without_details,
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    )

    # 既存のapplication_detailsは残る（実装によるが、現状は削除されない）
    assert_not_nil pesticide.pesticide_application_detail
    assert_equal detail_id, pesticide.pesticide_application_detail.id
    assert_equal original_ratio, pesticide.pesticide_application_detail.dilution_ratio
  end

  test "from_agrr_output should handle nil application_details" do
    pesticide_data_without_details = @pesticide_data.dup
    pesticide_data_without_details.delete("application_details")

    pesticide = Pesticide.from_agrr_output(
      pesticide_data: pesticide_data_without_details,
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    )

    assert_nil pesticide.pesticide_application_detail
  end

  test "from_agrr_output should handle null values in usage_constraints" do
    pesticide_data_with_nulls = @pesticide_data.dup
    pesticide_data_with_nulls["usage_constraints"]["min_temperature"] = nil
    pesticide_data_with_nulls["usage_constraints"]["max_temperature"] = nil

    pesticide = Pesticide.from_agrr_output(
      pesticide_data: pesticide_data_with_nulls,
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    )

    assert_not_nil pesticide.pesticide_usage_constraint
    assert_nil pesticide.pesticide_usage_constraint.min_temperature
    assert_nil pesticide.pesticide_usage_constraint.max_temperature
  end

  test "from_agrr_output should update existing pesticide" do
    existing_pesticide = create(:pesticide, pesticide_id: "acetamiprid", name: "古い名前", crop: @crop, pest: @pest)

    pesticide = Pesticide.from_agrr_output(
      pesticide_data: @pesticide_data,
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    )

    assert_equal existing_pesticide.id, pesticide.id
    assert_equal "アセタミプリド", pesticide.name
  end

  test "from_agrr_output should update is_reference flag" do
    user = create(:user)
    existing_pesticide = create(:pesticide, pesticide_id: "acetamiprid", is_reference: false, user: user, crop: @crop, pest: @pest)

    pesticide = Pesticide.from_agrr_output(
      pesticide_data: @pesticide_data,
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    )

    assert_equal true, pesticide.is_reference
    assert_equal existing_pesticide.id, pesticide.id
  end

  test "from_agrr_output should raise error when pesticide_id is missing" do
    invalid_data = @pesticide_data.dup
    invalid_data.delete("pesticide_id")

    assert_raises(StandardError, "Invalid pesticide_data: 'pesticide_id' is required") do
      Pesticide.from_agrr_output(
        pesticide_data: invalid_data,
        crop_id: @crop.id,
        pest_id: @pest.id,
        is_reference: true
      )
    end
  end

  test "from_agrr_output should raise error when crop_id is missing" do
    assert_raises(StandardError, "crop_id is required") do
      Pesticide.from_agrr_output(
        pesticide_data: @pesticide_data,
        crop_id: nil,
        pest_id: @pest.id,
        is_reference: true
      )
    end
  end

  test "from_agrr_output should raise error when pest_id is missing" do
    assert_raises(StandardError, "pest_id is required") do
      Pesticide.from_agrr_output(
        pesticide_data: @pesticide_data,
        crop_id: @crop.id,
        pest_id: nil,
        is_reference: true
      )
    end
  end

  test "from_agrr_output should raise error when usage_constraints validation fails" do
    invalid_data = @pesticide_data.dup
    invalid_data["usage_constraints"]["min_temperature"] = 40.0
    invalid_data["usage_constraints"]["max_temperature"] = 35.0

    assert_raises(ActiveRecord::RecordInvalid) do
      Pesticide.from_agrr_output(
        pesticide_data: invalid_data,
        crop_id: @crop.id,
        pest_id: @pest.id,
        is_reference: true
      )
    end
  end

  test "from_agrr_output should raise error when application_details validation fails" do
    invalid_data = @pesticide_data.dup
    invalid_data["application_details"]["amount_per_m2"] = 0.1
    invalid_data["application_details"]["amount_unit"] = nil

    assert_raises(ActiveRecord::RecordInvalid) do
      Pesticide.from_agrr_output(
        pesticide_data: invalid_data,
        crop_id: @crop.id,
        pest_id: @pest.id,
        is_reference: true
      )
    end
  end

  test "from_agrr_output should update existing usage_constraints" do
    existing_pesticide = create(:pesticide, pesticide_id: "acetamiprid", crop: @crop, pest: @pest)
    create(:pesticide_usage_constraint, pesticide: existing_pesticide, min_temperature: 10.0, max_temperature: 40.0)
    original_min_temp = existing_pesticide.reload.pesticide_usage_constraint.min_temperature

    pesticide = Pesticide.from_agrr_output(
      pesticide_data: @pesticide_data,
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    )

    assert_not_equal original_min_temp, pesticide.pesticide_usage_constraint.min_temperature
    assert_equal 5.0, pesticide.pesticide_usage_constraint.min_temperature
  end

  test "from_agrr_output should update existing application_details" do
    existing_pesticide = create(:pesticide, pesticide_id: "acetamiprid", crop: @crop, pest: @pest)
    create(:pesticide_application_detail, pesticide: existing_pesticide, dilution_ratio: "2000倍")
    original_ratio = existing_pesticide.reload.pesticide_application_detail.dilution_ratio

    pesticide = Pesticide.from_agrr_output(
      pesticide_data: @pesticide_data,
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    )

    assert_not_equal original_ratio, pesticide.pesticide_application_detail.dilution_ratio
    assert_equal "1000倍", pesticide.pesticide_application_detail.dilution_ratio
  end

  # to_agrr_output テスト（agrr CLI出力形式に変換）
  test "should convert to agrr output format" do
    pesticide = create(:pesticide, :complete, pesticide_id: "acetamiprid")

    output = pesticide.to_agrr_output

    assert_equal "acetamiprid", output["pesticide_id"]
    assert_equal pesticide.crop_id.to_s, output["crop_id"]
    assert_equal pesticide.pest.id.to_s, output["pest_id"]
    assert_equal pesticide.name, output["name"]
    assert_equal pesticide.active_ingredient, output["active_ingredient"]
    assert_equal pesticide.description, output["description"]

    assert_not_nil output["usage_constraints"]
    assert_equal pesticide.pesticide_usage_constraint.min_temperature, output["usage_constraints"]["min_temperature"]
    assert_equal pesticide.pesticide_usage_constraint.max_temperature, output["usage_constraints"]["max_temperature"]

    assert_not_nil output["application_details"]
    assert_equal pesticide.pesticide_application_detail.dilution_ratio, output["application_details"]["dilution_ratio"]
    assert_equal pesticide.pesticide_application_detail.amount_per_m2, output["application_details"]["amount_per_m2"]
  end

  test "to_agrr_output should handle nil usage_constraints" do
    pesticide = create(:pesticide, pesticide_id: "test_pesticide")

    output = pesticide.to_agrr_output

    assert_nil output["usage_constraints"]
  end

  test "to_agrr_output should handle nil application_details" do
    pesticide = create(:pesticide, pesticide_id: "test_pesticide")

    output = pesticide.to_agrr_output

    assert_nil output["application_details"]
  end

  test "to_agrr_output should handle nil values in usage_constraints" do
    pesticide = create(:pesticide, :with_usage_constraint, pesticide_id: "test_pesticide")
    pesticide.pesticide_usage_constraint.update(min_temperature: nil, max_temperature: nil)

    output = pesticide.to_agrr_output

    assert_nil output["usage_constraints"]["min_temperature"]
    assert_nil output["usage_constraints"]["max_temperature"]
  end

  test "to_agrr_output should handle usage_constraints with all nil values" do
    pesticide = create(:pesticide, pesticide_id: "test_pesticide")
    create(:pesticide_usage_constraint,
           pesticide: pesticide,
           min_temperature: nil,
           max_temperature: nil,
           max_wind_speed_m_s: nil,
           max_application_count: nil,
           harvest_interval_days: nil,
           other_constraints: nil)

    output = pesticide.to_agrr_output

    assert_not_nil output["usage_constraints"]
    assert_nil output["usage_constraints"]["min_temperature"]
    assert_nil output["usage_constraints"]["max_temperature"]
    assert_nil output["usage_constraints"]["max_wind_speed_m_s"]
    assert_nil output["usage_constraints"]["max_application_count"]
    assert_nil output["usage_constraints"]["harvest_interval_days"]
    assert_nil output["usage_constraints"]["other_constraints"]
  end

  test "to_agrr_output should include all usage_constraints fields" do
    pesticide = create(:pesticide, :with_usage_constraint, pesticide_id: "test_pesticide")

    output = pesticide.to_agrr_output

    constraints = output["usage_constraints"]
    assert_not_nil constraints
    assert_equal pesticide.pesticide_usage_constraint.min_temperature, constraints["min_temperature"]
    assert_equal pesticide.pesticide_usage_constraint.max_temperature, constraints["max_temperature"]
    assert_equal pesticide.pesticide_usage_constraint.max_wind_speed_m_s, constraints["max_wind_speed_m_s"]
    assert_equal pesticide.pesticide_usage_constraint.max_application_count, constraints["max_application_count"]
    assert_equal pesticide.pesticide_usage_constraint.harvest_interval_days, constraints["harvest_interval_days"]
    assert_nil constraints["other_constraints"]
    assert_nil pesticide.pesticide_usage_constraint.other_constraints
  end

  test "to_agrr_output should include all application_details fields" do
    pesticide = create(:pesticide, :with_application_detail, pesticide_id: "test_pesticide")

    output = pesticide.to_agrr_output

    details = output["application_details"]
    assert_not_nil details
    assert_equal pesticide.pesticide_application_detail.dilution_ratio, details["dilution_ratio"]
    assert_equal pesticide.pesticide_application_detail.amount_per_m2, details["amount_per_m2"]
    assert_equal pesticide.pesticide_application_detail.amount_unit, details["amount_unit"]
    assert_equal pesticide.pesticide_application_detail.application_method, details["application_method"]
  end

  # pesticide_id形式の多様性テスト
  test "from_agrr_output should handle numeric pesticide_id" do
    pesticide_data_numeric = {
      "pesticide_id" => "001",
      "name" => "テスト農薬",
      "active_ingredient" => "テスト成分",
      "description" => "説明",
      "usage_constraints" => {
        "min_temperature" => 5.0,
        "max_temperature" => 35.0,
        "max_wind_speed_m_s" => 3.0,
        "max_application_count" => 3,
        "harvest_interval_days" => 1,
        "other_constraints" => nil
      },
      "application_details" => {
        "dilution_ratio" => "1000倍",
        "amount_per_m2" => 0.1,
        "amount_unit" => "ml",
        "application_method" => "散布"
      }
    }

    pesticide = Pesticide.from_agrr_output(
      pesticide_data: pesticide_data_numeric,
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    )

    assert pesticide.persisted?
    assert_equal "001", pesticide.pesticide_id
    assert_equal "テスト農薬", pesticide.name

    found_pesticide = Pesticide.find_by(pesticide_id: "001")
    assert_equal pesticide.id, found_pesticide.id
  end

  test "from_agrr_output should handle pesticide_id with underscore" do
    pesticide_data_underscore = {
      "pesticide_id" => "imidacloprid_001",
      "name" => "イミダクロプリド",
      "active_ingredient" => "イミダクロプリド",
      "description" => "説明",
      "usage_constraints" => nil,
      "application_details" => nil
    }

    pesticide = Pesticide.from_agrr_output(
      pesticide_data: pesticide_data_underscore,
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    )

    assert pesticide.persisted?
    assert_equal "imidacloprid_001", pesticide.pesticide_id
    assert_equal "イミダクロプリド", pesticide.name

    found_pesticide = Pesticide.find_by(pesticide_id: "imidacloprid_001")
    assert_equal pesticide.id, found_pesticide.id
  end

  test "pesticide_id uniqueness should work with different formats and scopes" do
    crop1 = create(:crop, is_reference: true)
    crop2 = create(:crop, is_reference: true)
    pest1 = create(:pest, is_reference: true)
    pest2 = create(:pest, is_reference: true)
    
    create(:pesticide, pesticide_id: "001", crop: crop1, pest: pest1)
    create(:pesticide, pesticide_id: "acetamiprid", crop: crop1, pest: pest1)
    create(:pesticide, pesticide_id: "imidacloprid_001", crop: crop1, pest: pest1)

    assert_equal 3, Pesticide.count

    # 同じpesticide_id、crop_id、pest_idの組み合わせは重複エラー
    duplicate = Pesticide.new(pesticide_id: "001", name: "重複", crop: crop1, pest: pest1, is_reference: true)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:pesticide_id], "はすでに存在します"
    
    # 異なるcrop_idまたはpest_idの場合は有効
    valid = Pesticide.new(pesticide_id: "001", name: "有効", crop: crop2, pest: pest1, is_reference: true)
    assert valid.valid?
    
    valid2 = Pesticide.new(pesticide_id: "001", name: "有効2", crop: crop1, pest: pest2, is_reference: true)
    assert valid2.valid?
  end

  # スコープテスト
  test "reference scope should return reference pesticides" do
    user = create(:user)
    crop = create(:crop, is_reference: true)
    pest = create(:pest, is_reference: true)
    reference_pesticide = create(:pesticide, is_reference: true, crop: crop, pest: pest)
    user_pesticide = create(:pesticide, is_reference: false, user: user, crop: crop, pest: pest)

    reference_pesticides = Pesticide.reference

    assert_includes reference_pesticides, reference_pesticide
    assert_not_includes reference_pesticides, user_pesticide
  end

  test "user_owned scope should return only user-owned pesticides" do
    user = create(:user)
    crop = create(:crop, is_reference: true)
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
        _destroy: '1'
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
        _destroy: '1'
      }
    )

    assert_not PesticideApplicationDetail.exists?(detail_id)
  end

  # Pesticide経由でのバリデーションエラー検出
  test "should validate usage_constraint temperature constraints through pesticide" do
    pesticide = build(:pesticide, pesticide_id: "test_pesticide")
    pesticide.build_pesticide_usage_constraint(
      min_temperature: 40.0,
      max_temperature: 35.0
    )

    assert_not pesticide.valid?
    assert_includes pesticide.pesticide_usage_constraint.errors[:min_temperature],
                    "must be less than or equal to max_temperature"
  end

  test "should validate application_detail amount and unit consistency through pesticide" do
    pesticide = build(:pesticide, pesticide_id: "test_pesticide")
    pesticide.build_pesticide_application_detail(
      amount_per_m2: 0.1,
      amount_unit: nil
    )

    assert_not pesticide.valid?
    assert_includes pesticide.pesticide_application_detail.errors[:amount_per_m2],
                    "requires amount_unit"
  end
end

