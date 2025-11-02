# frozen_string_literal: true

require "test_helper"

class CropTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  test "should prevent creating 21st crop for user" do
    # Create 20 crops (上限)
    20.times do |i|
      create(:crop, user: @user, name: "作物 #{i+1}", is_reference: false)
    end
    
    # Attempt to create 21st crop
    crop = Crop.new(user: @user, name: "作物 21", is_reference: false)
    assert_not crop.valid?
    assert_includes crop.errors[:user], "作成できるCropは20件までです"
  end

  test "should allow creating crops when under limit" do
    # Create 19 crops
    19.times do |i|
      create(:crop, user: @user, name: "作物 #{i+1}", is_reference: false)
    end
    
    # 20th crop should be valid
    crop = Crop.new(user: @user, name: "作物 20", is_reference: false)
    assert crop.valid?
  end

  test "should not count reference crops towards limit" do
    # Create 20 reference crops
    20.times do |i|
      create(:crop, name: "参照作物 #{i+1}", is_reference: true, user: nil)
    end
    
    # User should still be able to create 20 crops
    crop = Crop.new(user: @user, name: "ユーザー作物", is_reference: false)
    assert crop.valid?
  end

  test "should allow updating existing crop" do
    # Create 20 crops
    20.times do |i|
      create(:crop, user: @user, name: "作物 #{i+1}", is_reference: false)
    end
    
    # Update should work (自分自身を除く)
    first_crop = @user.crops.first
    first_crop.name = "更新された作物"
    assert first_crop.valid?
  end

  test "should allow different users to have their own 20 crops" do
    @user2 = create(:user)
    
    # Each user creates 20 crops
    20.times do |i|
      create(:crop, user: @user, name: "User1 作物 #{i+1}", is_reference: false)
      create(:crop, user: @user2, name: "User2 作物 #{i+1}", is_reference: false)
    end
    
    # Both users should be at limit
    assert_not Crop.new(user: @user, name: "New", is_reference: false).valid?
    assert_not Crop.new(user: @user2, name: "New", is_reference: false).valid?
  end

  test "should validate user presence for non-reference crops" do
    crop = Crop.new(user: nil, name: "作物", is_reference: false)
    # Should have validation error for missing user
    crop.valid? # triggers validations
    assert_equal 1, crop.errors[:user].count
    assert_includes crop.errors[:user], "を入力してください"
  end

  # Pest関連テスト
  test "should have many crop_pests" do
    crop = create(:crop)
    pest1 = create(:pest)
    pest2 = create(:pest)
    
    create(:crop_pest, crop: crop, pest: pest1)
    create(:crop_pest, crop: crop, pest: pest2)
    
    assert_equal 2, crop.crop_pests.count
  end

  test "should have many pests through crop_pests" do
    crop = create(:crop)
    pest1 = create(:pest)
    pest2 = create(:pest)
    
    create(:crop_pest, crop: crop, pest: pest1)
    create(:crop_pest, crop: crop, pest: pest2)
    
    assert_equal 2, crop.pests.count
    assert_includes crop.pests, pest1
    assert_includes crop.pests, pest2
  end

  # associate_pests_from_agrr_output テスト
  test "should associate pests from agrr output" do
    crop = create(:crop, :tomato)
    
    pest_output_data = {
      "pests" => [
        {
          "pest_id" => "aphid",
          "name" => "アブラムシ",
          "name_scientific" => "Aphidoidea",
          "family" => "アブラムシ科",
          "order" => "半翅目",
          "description" => "アブラムシの説明",
          "temperature_profile" => {
            "base_temperature" => 5,
            "max_temperature" => 30
          },
          "thermal_requirement" => {
            "required_gdd" => 300,
            "first_generation_gdd" => 100
          },
          "control_methods" => [
            {
              "method_type" => "chemical",
              "method_name" => "殺虫剤",
              "description" => "説明",
              "timing_hint" => "発生初期に散布"
            }
          ],
          "occurrence_season" => "春〜秋"
        },
        {
          "pest_id" => "spider_mite",
          "name" => "ダニ",
          "name_scientific" => "Tetranychus urticae",
          "family" => "ダニ科",
          "order" => "クモ目",
          "description" => "ダニの説明",
          "temperature_profile" => {
            "base_temperature" => 10,
            "max_temperature" => 35
          },
          "thermal_requirement" => {
            "required_gdd" => 800,
            "first_generation_gdd" => 200
          },
          "control_methods" => [
            {
              "method_type" => "biological",
              "method_name" => "天敵の放飼",
              "description" => "説明",
              "timing_hint" => "発生が確認された時"
            }
          ],
          "occurrence_season" => "春〜秋"
        }
      ]
    }
    
    associated_pests = crop.associate_pests_from_agrr_output(pest_output_data: pest_output_data)
    
    assert_equal 2, associated_pests.count
    assert_equal 2, crop.pests.count
    assert_equal 2, crop.crop_pests.count
    
    aphid = crop.pests.find_by(name: "アブラムシ")
    assert_not_nil aphid
    assert_equal "アブラムシ", aphid.name
    assert_not_nil aphid.pest_temperature_profile
    assert_equal 5, aphid.pest_temperature_profile.base_temperature
    assert_equal 1, aphid.pest_control_methods.count
    
    spider_mite = crop.pests.find_by(name: "ダニ")
    assert_not_nil spider_mite
    assert_equal "ダニ", spider_mite.name
    assert_not_nil spider_mite.pest_thermal_requirement
    assert_equal 800, spider_mite.pest_thermal_requirement.required_gdd
  end

  test "associate_pests_from_agrr_output should not duplicate existing associations" do
    crop = create(:crop)
    existing_pest = create(:pest, name: "アブラムシ", is_reference: true)
    create(:crop_pest, crop: crop, pest: existing_pest)
    
    pest_output_data = {
      "pests" => [
        {
          "pest_id" => "aphid",
          "name" => "アブラムシ",
          "name_scientific" => "Aphidoidea",
          "family" => "アブラムシ科",
          "order" => "半翅目",
          "description" => "アブラムシの説明",
          "temperature_profile" => {
            "base_temperature" => 5,
            "max_temperature" => 30
          },
          "thermal_requirement" => {
            "required_gdd" => 300,
            "first_generation_gdd" => 100
          },
          "control_methods" => [],
          "occurrence_season" => "春〜秋"
        }
      ]
    }
    
    crop.associate_pests_from_agrr_output(pest_output_data: pest_output_data)
    
    # 既存の関連が残っていること、重複していないこと
    assert_equal 1, crop.crop_pests.count
    assert_equal 1, crop.pests.count
  end

  test "associate_pests_from_agrr_output should raise error when pests is not array" do
    crop = create(:crop)
    invalid_data = {
      "pests" => "not an array"
    }
    
    assert_raises(StandardError, "Invalid pest_output_data: 'pests' must be an array") do
      crop.associate_pests_from_agrr_output(pest_output_data: invalid_data)
    end
  end

  test "associate_pests_from_agrr_output should handle empty pests array" do
    crop = create(:crop)
    empty_data = {
      "pests" => []
    }
    
    associated_pests = crop.associate_pests_from_agrr_output(pest_output_data: empty_data)
    
    assert_equal 0, associated_pests.count
    assert_equal 0, crop.pests.count
  end

  test "associate_pests_from_agrr_output should update existing pests" do
    crop = create(:crop)
    existing_pest = create(:pest, name: "新しい名前", is_reference: true)
    
    pest_output_data = {
      "pests" => [
        {
          "pest_id" => "aphid",
          "name" => "新しい名前",  # 既存のpestと同じname
          "name_scientific" => "Aphidoidea",
          "family" => "アブラムシ科",
          "order" => "半翅目",
          "description" => "説明",
          "temperature_profile" => {
            "base_temperature" => 5,
            "max_temperature" => 30
          },
          "thermal_requirement" => {
            "required_gdd" => 300,
            "first_generation_gdd" => 100
          },
          "control_methods" => [],
          "occurrence_season" => "春〜秋"
        }
      ]
    }
    
    crop.associate_pests_from_agrr_output(pest_output_data: pest_output_data)
    
    existing_pest.reload
    assert_equal "新しい名前", existing_pest.name
    # 新しいpestが作成されず、既存のpestが更新されていること
    assert_equal 1, crop.pests.count
  end

  # 複数害虫の統合テスト（実際のagrr出力に基づく）
  test "associate_pests_from_agrr_output should handle 8 pests with various formats and null values" do
    crop = create(:crop, :tomato)
    
    # 実際のagrr出力に近い8つの害虫データ
    pest_output_data = {
      "pests" => [
        { "pest_id" => "aphid", "name" => "アブラムシ", "name_scientific" => "Aphidoidea", "family" => "アブラムシ科", "order" => "半翅目", "description" => "説明", "temperature_profile" => { "base_temperature" => 5, "max_temperature" => 30 }, "thermal_requirement" => { "required_gdd" => 300, "first_generation_gdd" => 100 }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "physical", "method_name" => "水洗い", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" },
        { "pest_id" => "001", "name" => "ハダニ", "name_scientific" => "Bemisia tabaci", "family" => "アザミウマ科", "order" => "半翅目", "description" => "説明", "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 35 }, "thermal_requirement" => { "required_gdd" => 800, "first_generation_gdd" => 300 }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "農薬", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" },
        { "pest_id" => "leafminer", "name" => "リーフマイナー", "name_scientific" => "Liriomyza spp.", "family" => "ウリ科", "order" => "双翅目", "description" => "説明", "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 30 }, "thermal_requirement" => { "required_gdd" => 300, "first_generation_gdd" => nil }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" },
        { "pest_id" => "spider_mite", "name" => "ダニ", "name_scientific" => "Tetranychus urticae", "family" => "ダニ科", "order" => "クモ目", "description" => "説明", "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 35 }, "thermal_requirement" => { "required_gdd" => 800, "first_generation_gdd" => 200 }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" },
        { "pest_id" => "thrips", "name" => "スリップス", "name_scientific" => "Thysanoptera", "family" => "スリップス科", "order" => "トリコプテル目", "description" => "説明", "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 35 }, "thermal_requirement" => { "required_gdd" => 800, "first_generation_gdd" => 200 }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "physical", "method_name" => "粘着トラップ", "description" => "説明", "timing_hint" => "発生時期" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" },
        { "pest_id" => "cutworm", "name" => "カットワーム", "name_scientific" => "Agrotis spp.", "family" => "ノミバエ科", "order" => "チョウ目", "description" => "説明", "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 30 }, "thermal_requirement" => { "required_gdd" => 300, "first_generation_gdd" => nil }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" },
        { "pest_id" => "hornworm_001", "name" => "ホーンワーム", "name_scientific" => "Manduca sexta", "family" => "ナス科", "order" => "チョウ目", "description" => "説明", "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 35 }, "thermal_requirement" => { "required_gdd" => 800, "first_generation_gdd" => 300 }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" },
        { "pest_id" => "white_grub", "name" => "シロアリ", "name_scientific" => "Phyllophaga spp.", "family" => "コガネムシ科", "order" => "甲虫目", "description" => "説明", "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 30 }, "thermal_requirement" => { "required_gdd" => 300, "first_generation_gdd" => nil }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" }
      ]
    }
    
    associated_pests = crop.associate_pests_from_agrr_output(pest_output_data: pest_output_data)
    
    assert_equal 8, associated_pests.count
    assert_equal 8, crop.pests.count
    assert_equal 8, crop.crop_pests.count
    
    # 異なるpest_id形式がすべて正しく処理されていること（nameで検索）
    assert_not_nil crop.pests.find_by(name: "アブラムシ") # 英単語
    assert_not_nil crop.pests.find_by(name: "ハダニ") # 数字のみ
    assert_not_nil crop.pests.find_by(name: "ホーンワーム") # アンダースコア
    
    # control_methodsの数の違いが正しく処理されていること
    aphid = crop.pests.find_by(name: "アブラムシ")
    thrips = crop.pests.find_by(name: "スリップス")
    assert_equal 4, aphid.pest_control_methods.count
    assert_equal 4, thrips.pest_control_methods.count
    
    numeric_pest = crop.pests.find_by(name: "ハダニ")
    assert_equal 3, numeric_pest.pest_control_methods.count
    
    # physicalタイプが正しく処理されていること
    assert_not_nil aphid.pest_control_methods.find_by(method_type: "physical")
    assert_not_nil thrips.pest_control_methods.find_by(method_type: "physical")
    
    # first_generation_gddがnullの害虫が正しく処理されていること
    leafminer = crop.pests.find_by(name: "リーフマイナー")
    cutworm = crop.pests.find_by(name: "カットワーム")
    white_grub = crop.pests.find_by(name: "シロアリ")
    
    assert_nil leafminer.pest_thermal_requirement.first_generation_gdd
    assert_nil cutworm.pest_thermal_requirement.first_generation_gdd
    assert_nil white_grub.pest_thermal_requirement.first_generation_gdd
    
    # first_generation_gddが設定されている害虫も正しく処理されていること
    assert_equal 100, aphid.pest_thermal_requirement.first_generation_gdd
    assert_equal 300, numeric_pest.pest_thermal_requirement.first_generation_gdd
  end
end
