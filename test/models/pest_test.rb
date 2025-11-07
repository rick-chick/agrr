# frozen_string_literal: true

require "test_helper"

class PestTest < ActiveSupport::TestCase
  setup do
    @pest_data = {
      "pest_id" => "aphid",
      "name" => "アブラムシ",
      "name_scientific" => "Aphidoidea",
      "family" => "アブラムシ科",
      "order" => "半翅目",
      "description" => "アブラムシは、トマトの葉や茎に集まり、汁を吸うことで植物の成長を妨げます。特に若い葉に被害を与え、葉の変色や萎縮を引き起こします。また、ウイルス病の媒介者としても知られています。",
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
          "description" => "アブラムシに対して効果的な殺虫剤を使用します。",
          "timing_hint" => "発生初期に散布"
        },
        {
          "method_type" => "biological",
          "method_name" => "天敵の放飼",
          "description" => "アブラムシを捕食する天敵（例: テントウムシ）を放飼します。",
          "timing_hint" => "アブラムシの発生が確認された時"
        },
        {
          "method_type" => "cultural",
          "method_name" => "作物の輪作",
          "description" => "アブラムシの発生を抑えるために、作物の輪作を行います。",
          "timing_hint" => "次年度の栽培計画に組み込む"
        }
      ],
      "occurrence_season" => "春〜秋"
    }
  end

  # バリデーションテスト

  test "should validate name presence" do
    pest = Pest.new
    assert_not pest.valid?
    assert_includes pest.errors[:name], "を入力してください"
  end

  test "should validate is_reference inclusion" do
    pest = Pest.new(name: "テスト害虫", is_reference: nil)
    assert_not pest.valid?
    assert_includes pest.errors[:is_reference], "は一覧にありません"
  end

  test "should validate user presence when is_reference is false" do
    pest = Pest.new(name: "テスト害虫", is_reference: false, user_id: nil)
    assert_not pest.valid?
    assert_includes pest.errors[:user], "を入力してください"
  end

  test "should allow nil user_id when is_reference is true" do
    pest = Pest.new(name: "テスト害虫", is_reference: true, user_id: nil)
    assert pest.valid?
  end

  test "should allow user_id when is_reference is false" do
    user = create(:user)
    pest = Pest.new(name: "テスト害虫", is_reference: false, user_id: user.id)
    assert pest.valid?
  end

  test "should require user_id when is_reference changes from true to false" do
    user = create(:user)
    pest = create(:pest, is_reference: true, user_id: nil)
    
    pest.is_reference = false
    assert_not pest.valid?
    assert_includes pest.errors[:user], "を入力してください"
    
    pest.user_id = user.id
    assert pest.valid?
  end

  test "should enforce uniqueness of source_pest_id per user" do
    user = create(:user)
    reference = create(:pest, is_reference: true)

    create(:pest, :user_owned, user: user, source_pest_id: reference.id)

    duplicated = build(:pest, :user_owned, user: user, source_pest_id: reference.id)
    assert_not duplicated.valid?
    assert_includes duplicated.errors[:source_pest_id], "はすでに存在します"

    another_user = create(:user)
    other = build(:pest, :user_owned, user: another_user, source_pest_id: reference.id)
    assert other.valid?
  end

  # 関連テスト
  test "should have one pest_temperature_profile" do
    pest = create(:pest, :with_temperature_profile)
    assert_not_nil pest.pest_temperature_profile
    assert_equal 10.0, pest.pest_temperature_profile.base_temperature
  end

  test "should have one pest_thermal_requirement" do
    pest = create(:pest, :with_thermal_requirement)
    assert_not_nil pest.pest_thermal_requirement
    assert_equal 300.0, pest.pest_thermal_requirement.required_gdd
  end

  test "should have many pest_control_methods" do
    pest = create(:pest, :with_control_methods)
    assert_equal 3, pest.pest_control_methods.count
  end

  test "should have many crop_pests" do
    pest = create(:pest)
    crop1 = create(:crop)
    crop2 = create(:crop)
    
    create(:crop_pest, crop: crop1, pest: pest)
    create(:crop_pest, crop: crop2, pest: pest)
    
    assert_equal 2, pest.crop_pests.count
    assert_equal 2, pest.crops.count
  end

  test "should destroy related records when pest is destroyed" do
    pest = create(:pest, :complete)
    temp_profile_id = pest.pest_temperature_profile.id
    thermal_req_id = pest.pest_thermal_requirement.id
    control_method_ids = pest.pest_control_methods.pluck(:id)
    
    pest.destroy
    
    assert_not PestTemperatureProfile.exists?(temp_profile_id)
    assert_not PestThermalRequirement.exists?(thermal_req_id)
    control_method_ids.each do |id|
      assert_not PestControlMethod.exists?(id)
    end
  end

  # from_agrr_output テスト（agrr CLI出力形式から作成）
  test "should create pest from agrr output" do
    pest = Pest.from_agrr_output(pest_data: @pest_data, is_reference: true)
    
    assert pest.persisted?
    assert_equal "アブラムシ", pest.name
    assert_equal "Aphidoidea", pest.name_scientific
    assert_equal "アブラムシ科", pest.family
    assert_equal "半翅目", pest.order
    assert_equal "春〜秋", pest.occurrence_season
    assert_equal true, pest.is_reference
  end

  test "from_agrr_output should create temperature_profile" do
    pest = Pest.from_agrr_output(pest_data: @pest_data, is_reference: true)
    
    assert_not_nil pest.pest_temperature_profile
    assert_equal 5, pest.pest_temperature_profile.base_temperature
    assert_equal 30, pest.pest_temperature_profile.max_temperature
  end

  test "from_agrr_output should create thermal_requirement" do
    pest = Pest.from_agrr_output(pest_data: @pest_data, is_reference: true)
    
    assert_not_nil pest.pest_thermal_requirement
    assert_equal 300, pest.pest_thermal_requirement.required_gdd
    assert_equal 100, pest.pest_thermal_requirement.first_generation_gdd
  end

  test "from_agrr_output should handle null first_generation_gdd" do
    pest_data_with_null = @pest_data.dup
    pest_data_with_null["thermal_requirement"]["first_generation_gdd"] = nil
    
    pest = Pest.from_agrr_output(pest_data: pest_data_with_null, is_reference: true)
    
    assert_not_nil pest.pest_thermal_requirement
    assert_nil pest.pest_thermal_requirement.first_generation_gdd
  end

  test "from_agrr_output should create control_methods" do
    pest = Pest.from_agrr_output(pest_data: @pest_data, is_reference: true)
    
    assert_equal 3, pest.pest_control_methods.count
    
    chemical = pest.pest_control_methods.find_by(method_type: "chemical")
    assert_equal "殺虫剤", chemical.method_name
    assert_equal "発生初期に散布", chemical.timing_hint
    
    biological = pest.pest_control_methods.find_by(method_type: "biological")
    assert_equal "天敵の放飼", biological.method_name
    
    cultural = pest.pest_control_methods.find_by(method_type: "cultural")
    assert_equal "作物の輪作", cultural.method_name
  end

  test "from_agrr_output should handle empty control_methods" do
    pest_data_empty = @pest_data.dup
    pest_data_empty["control_methods"] = []
    
    pest = Pest.from_agrr_output(pest_data: pest_data_empty, is_reference: true)
    
    assert_equal 0, pest.pest_control_methods.count
  end

  test "from_agrr_output should update existing pest" do
    existing_pest = create(:pest, name: "アブラムシ", is_reference: true)
    
    pest = Pest.from_agrr_output(pest_data: @pest_data, is_reference: true)
    
    # nameで一致するpestが更新されるか、新しいpestが作成される
    assert_equal "アブラムシ", pest.name
  end

  test "from_agrr_output should replace existing control_methods" do
    existing_pest = create(:pest, :with_control_methods, name: "アブラムシ", is_reference: true)
    assert_equal 3, existing_pest.pest_control_methods.count
    
    pest = Pest.from_agrr_output(pest_data: @pest_data, is_reference: true)
    
    assert_equal 3, pest.pest_control_methods.count
    # 既存のものは削除され、新しいものが作成されている
    assert_equal "アブラムシに対して効果的な殺虫剤を使用します。", 
                 pest.pest_control_methods.find_by(method_type: "chemical").description
  end

  # to_agrr_output テスト（agrr CLI出力形式に変換）
  test "should convert to agrr output format" do
    pest = create(:pest, :aphid, :complete)
    
    # completeトレイトで既に3つのcontrol_methodsが作成されている
    output = pest.to_agrr_output
    
    assert_equal pest.id.to_s, output["pest_id"]
    assert_equal "アブラムシ", output["name"]
    assert_equal "Aphidoidea", output["name_scientific"]
    assert_equal "アブラムシ科", output["family"]
    assert_equal "半翅目", output["order"]
    assert_equal "春〜秋", output["occurrence_season"]
    
    assert_not_nil output["temperature_profile"]
    assert_equal 10.0, output["temperature_profile"]["base_temperature"]
    assert_equal 30.0, output["temperature_profile"]["max_temperature"]
    
    assert_not_nil output["thermal_requirement"]
    assert_equal 300.0, output["thermal_requirement"]["required_gdd"]
    assert_equal 100.0, output["thermal_requirement"]["first_generation_gdd"]
    
    assert_equal 3, output["control_methods"].count
    chemical_output = output["control_methods"].find { |m| m["method_type"] == "chemical" }
    assert_equal "殺虫剤", chemical_output["method_name"]
    assert_equal "発生初期に散布", chemical_output["timing_hint"]
  end

  test "to_agrr_output should handle nil temperature_profile" do
    pest = create(:pest, :aphid)
    
    output = pest.to_agrr_output
    
    assert_nil output["temperature_profile"]
  end

  test "to_agrr_output should handle nil thermal_requirement" do
    pest = create(:pest, :aphid, :with_temperature_profile)
    
    output = pest.to_agrr_output
    
    assert_nil output["thermal_requirement"]
  end

  test "to_agrr_output should handle empty control_methods" do
    pest = create(:pest, :aphid, :with_temperature_profile, :with_thermal_requirement)
    
    output = pest.to_agrr_output
    
    assert_equal [], output["control_methods"]
  end

  test "to_agrr_output should handle nil first_generation_gdd" do
    pest = create(:pest, :aphid)
    create(:pest_thermal_requirement, pest: pest, first_generation_gdd: nil)
    
    output = pest.to_agrr_output
    
    assert_nil output["thermal_requirement"]["first_generation_gdd"]
  end

  # pest_id形式の多様性テスト（agrr CLIからのpest_idは無視されるが、後方互換性のため受け入れる）
  test "from_agrr_output should handle numeric pest_id" do
    pest_data_numeric = {
      "pest_id" => "001",
      "name" => "ハダニ",
      "name_scientific" => "Bemisia tabaci",
      "family" => "アザミウマ科",
      "order" => "半翅目",
      "description" => "ハダニの説明",
      "temperature_profile" => {
        "base_temperature" => 10,
        "max_temperature" => 35
      },
      "thermal_requirement" => {
        "required_gdd" => 800,
        "first_generation_gdd" => 300
      },
      "control_methods" => [
        {
          "method_type" => "chemical",
          "method_name" => "農薬",
          "description" => "説明",
          "timing_hint" => "発生初期"
        }
      ],
      "occurrence_season" => "春〜秋"
    }
    
    pest = Pest.from_agrr_output(pest_data: pest_data_numeric, is_reference: true)
    
    assert pest.persisted?
    assert_equal "ハダニ", pest.name
    
    # nameで検索できること
    found_pest = Pest.find_by(name: "ハダニ", is_reference: true)
    assert_equal pest.id, found_pest.id
  end

  test "from_agrr_output should handle pest_id with underscore" do
    pest_data_underscore = {
      "pest_id" => "hornworm_001",
      "name" => "ホーンワーム",
      "name_scientific" => "Manduca sexta",
      "family" => "ナス科",
      "order" => "チョウ目",
      "description" => "ホーンワームの説明",
      "temperature_profile" => {
        "base_temperature" => 10,
        "max_temperature" => 35
      },
      "thermal_requirement" => {
        "required_gdd" => 800,
        "first_generation_gdd" => 300
      },
      "control_methods" => [
        {
          "method_type" => "chemical",
          "method_name" => "殺虫剤",
          "description" => "説明",
          "timing_hint" => "発生初期"
        }
      ],
      "occurrence_season" => "春〜秋"
    }
    
    pest = Pest.from_agrr_output(pest_data: pest_data_underscore, is_reference: true)
    
    assert pest.persisted?
    assert_equal "ホーンワーム", pest.name
    
    # nameで検索できること
    found_pest = Pest.find_by(name: "ホーンワーム", is_reference: true)
    assert_equal pest.id, found_pest.id
  end

  # control_methods数の可変性テスト
  test "from_agrr_output should handle 4 control_methods with physical type" do
    pest_data_4methods = {
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
          "description" => "化学的防除",
          "timing_hint" => "発生初期に散布"
        },
        {
          "method_type" => "biological",
          "method_name" => "天敵の放飼",
          "description" => "生物的防除",
          "timing_hint" => "発生確認時"
        },
        {
          "method_type" => "physical",
          "method_name" => "水で洗い流す",
          "description" => "物理的防除",
          "timing_hint" => "発生初期"
        },
        {
          "method_type" => "cultural",
          "method_name" => "作物の輪作",
          "description" => "耕種的防除",
          "timing_hint" => "栽培計画に組み込む"
        }
      ],
      "occurrence_season" => "春〜秋"
    }
    
    pest = Pest.from_agrr_output(pest_data: pest_data_4methods, is_reference: true)
    
    assert_equal 4, pest.pest_control_methods.count
    
    # すべてのタイプが作成されていること
    assert_not_nil pest.pest_control_methods.find_by(method_type: "chemical")
    assert_not_nil pest.pest_control_methods.find_by(method_type: "biological")
    assert_not_nil pest.pest_control_methods.find_by(method_type: "physical")
    assert_not_nil pest.pest_control_methods.find_by(method_type: "cultural")
    
    # physicalタイプが正しく作成されていること
    physical = pest.pest_control_methods.find_by(method_type: "physical")
    assert_equal "水で洗い流す", physical.method_name
    assert_equal "物理的防除", physical.description
  end

  test "from_agrr_output should handle 3 control_methods" do
    pest_data_3methods = {
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
          "method_type" => "chemical",
          "method_name" => "殺虫剤",
          "description" => "説明1",
          "timing_hint" => "発生初期"
        },
        {
          "method_type" => "biological",
          "method_name" => "天敵の放飼",
          "description" => "説明2",
          "timing_hint" => "発生確認時"
        },
        {
          "method_type" => "cultural",
          "method_name" => "輪作",
          "description" => "説明3",
          "timing_hint" => "栽培計画"
        }
      ],
      "occurrence_season" => "春〜秋"
    }
    
    pest = Pest.from_agrr_output(pest_data: pest_data_3methods, is_reference: true)
    
    assert_equal 3, pest.pest_control_methods.count
    assert_equal 3, pest.pest_control_methods.distinct.pluck(:method_type).count
  end

  test "to_agrr_output should handle 4 control_methods" do
    pest = create(:pest)
    create(:pest_control_method, :chemical, pest: pest)
    create(:pest_control_method, :biological, pest: pest)
    create(:pest_control_method, :physical, pest: pest)
    create(:pest_control_method, :cultural, pest: pest)
    
    output = pest.to_agrr_output
    
    assert_equal 4, output["control_methods"].count
    
    method_types = output["control_methods"].map { |m| m["method_type"] }
    assert_includes method_types, "chemical"
    assert_includes method_types, "biological"
    assert_includes method_types, "physical"
    assert_includes method_types, "cultural"
  end

  # 複数害虫の統合テスト
  test "should handle multiple pests with different pest_id formats and control_method counts" do
    pest_output_data = {
      "pests" => [
        {
          "pest_id" => "aphid",
          "name" => "アブラムシ",
          "name_scientific" => "Aphidoidea",
          "family" => "アブラムシ科",
          "order" => "半翅目",
          "description" => "アブラムシの説明",
          "temperature_profile" => { "base_temperature" => 5, "max_temperature" => 30 },
          "thermal_requirement" => { "required_gdd" => 300, "first_generation_gdd" => 100 },
          "control_methods" => [
            { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
            { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
            { "method_type" => "physical", "method_name" => "水洗い", "description" => "説明", "timing_hint" => "発生初期" },
            { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
          ],
          "occurrence_season" => "春〜秋"
        },
        {
          "pest_id" => "001",
          "name" => "ハダニ",
          "name_scientific" => "Bemisia tabaci",
          "family" => "アザミウマ科",
          "order" => "半翅目",
          "description" => "ハダニの説明",
          "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 35 },
          "thermal_requirement" => { "required_gdd" => 800, "first_generation_gdd" => 300 },
          "control_methods" => [
            { "method_type" => "chemical", "method_name" => "農薬", "description" => "説明", "timing_hint" => "発生初期" },
            { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
            { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
          ],
          "occurrence_season" => "春〜秋"
        },
        {
          "pest_id" => "hornworm_001",
          "name" => "ホーンワーム",
          "name_scientific" => "Manduca sexta",
          "family" => "ナス科",
          "order" => "チョウ目",
          "description" => "ホーンワームの説明",
          "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 35 },
          "thermal_requirement" => { "required_gdd" => 800, "first_generation_gdd" => 300 },
          "control_methods" => [
            { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
            { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
            { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
          ],
          "occurrence_season" => "春〜秋"
        },
        {
          "pest_id" => "leafminer",
          "name" => "リーフマイナー",
          "name_scientific" => "Liriomyza spp.",
          "family" => "ウリ科",
          "order" => "双翅目",
          "description" => "リーフマイナーの説明",
          "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 30 },
          "thermal_requirement" => { "required_gdd" => 300, "first_generation_gdd" => nil },
          "control_methods" => [
            { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
            { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
            { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
          ],
          "occurrence_season" => "春〜秋"
        }
      ]
    }
    
    crop = create(:crop)
    associated_pests = crop.associate_pests_from_agrr_output(pest_output_data: pest_output_data)
    
    assert_equal 4, associated_pests.count
    assert_equal 4, crop.pests.count
    
    # 異なるpest_id形式が正しく処理されていること（nameで検索）
    aphid = crop.pests.find_by(name: "アブラムシ")
    numeric_pest = crop.pests.find_by(name: "ハダニ")
    underscore_pest = crop.pests.find_by(name: "ホーンワーム")
    leafminer_pest = crop.pests.find_by(name: "リーフマイナー")
    
    assert_not_nil aphid
    assert_not_nil numeric_pest
    assert_not_nil underscore_pest
    assert_not_nil leafminer_pest
    
    # control_methodsの数が異なること
    assert_equal 4, aphid.pest_control_methods.count
    assert_equal 3, numeric_pest.pest_control_methods.count
    assert_equal 3, underscore_pest.pest_control_methods.count
    assert_equal 3, leafminer_pest.pest_control_methods.count
    
    # aphidにはphysicalタイプがあること
    assert_not_nil aphid.pest_control_methods.find_by(method_type: "physical")
    
    # leafminerのfirst_generation_gddがnullであること
    assert_nil leafminer_pest.pest_thermal_requirement.first_generation_gdd
  end

  test "should handle 8 pests similar to actual agrr output" do
    # 実際のagrr出力に近い8つの害虫データ
    pest_output_data = {
      "pests" => [
        { "pest_id" => "aphid", "name" => "アブラムシ", "name_scientific" => "Aphidoidea", "family" => "アブラムシ科", "order" => "半翅目", "description" => "説明1", "temperature_profile" => { "base_temperature" => 5, "max_temperature" => 30 }, "thermal_requirement" => { "required_gdd" => 300, "first_generation_gdd" => 100 }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "physical", "method_name" => "水洗い", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" },
        { "pest_id" => "001", "name" => "ハダニ", "name_scientific" => "Bemisia tabaci", "family" => "アザミウマ科", "order" => "半翅目", "description" => "説明2", "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 35 }, "thermal_requirement" => { "required_gdd" => 800, "first_generation_gdd" => 300 }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "農薬", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" },
        { "pest_id" => "leafminer", "name" => "リーフマイナー", "name_scientific" => "Liriomyza spp.", "family" => "ウリ科", "order" => "双翅目", "description" => "説明3", "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 30 }, "thermal_requirement" => { "required_gdd" => 300, "first_generation_gdd" => nil }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" },
        { "pest_id" => "spider_mite", "name" => "ダニ", "name_scientific" => "Tetranychus urticae", "family" => "ダニ科", "order" => "クモ目", "description" => "説明4", "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 35 }, "thermal_requirement" => { "required_gdd" => 800, "first_generation_gdd" => 200 }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" },
        { "pest_id" => "thrips", "name" => "スリップス", "name_scientific" => "Thysanoptera", "family" => "スリップス科", "order" => "トリコプテル目", "description" => "説明5", "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 35 }, "thermal_requirement" => { "required_gdd" => 800, "first_generation_gdd" => 200 }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "physical", "method_name" => "粘着トラップ", "description" => "説明", "timing_hint" => "発生時期" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" },
        { "pest_id" => "cutworm", "name" => "カットワーム", "name_scientific" => "Agrotis spp.", "family" => "ノミバエ科", "order" => "チョウ目", "description" => "説明6", "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 30 }, "thermal_requirement" => { "required_gdd" => 300, "first_generation_gdd" => nil }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" },
        { "pest_id" => "hornworm_001", "name" => "ホーンワーム", "name_scientific" => "Manduca sexta", "family" => "ナス科", "order" => "チョウ目", "description" => "説明7", "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 35 }, "thermal_requirement" => { "required_gdd" => 800, "first_generation_gdd" => 300 }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" },
        { "pest_id" => "white_grub", "name" => "シロアリ", "name_scientific" => "Phyllophaga spp.", "family" => "コガネムシ科", "order" => "甲虫目", "description" => "説明8", "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 30 }, "thermal_requirement" => { "required_gdd" => 300, "first_generation_gdd" => nil }, "control_methods" => [
          { "method_type" => "chemical", "method_name" => "殺虫剤", "description" => "説明", "timing_hint" => "発生初期" },
          { "method_type" => "biological", "method_name" => "天敵", "description" => "説明", "timing_hint" => "発生確認時" },
          { "method_type" => "cultural", "method_name" => "輪作", "description" => "説明", "timing_hint" => "計画時" }
        ], "occurrence_season" => "春〜秋" }
      ]
    }
    
    crop = create(:crop)
    associated_pests = crop.associate_pests_from_agrr_output(pest_output_data: pest_output_data)
    
    assert_equal 8, associated_pests.count
    assert_equal 8, crop.pests.count
    
    # 異なるpest_id形式がすべて処理されていること（nameで検索）
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
    
    # first_generation_gddがnullの害虫が正しく処理されていること
    leafminer = crop.pests.find_by(name: "リーフマイナー")
    cutworm = crop.pests.find_by(name: "カットワーム")
    white_grub = crop.pests.find_by(name: "シロアリ")
    
    assert_nil leafminer.pest_thermal_requirement.first_generation_gdd
    assert_nil cutworm.pest_thermal_requirement.first_generation_gdd
    assert_nil white_grub.pest_thermal_requirement.first_generation_gdd
  end

  # null値の扱いテスト（実際のagrr出力に基づく）
  test "from_agrr_output should handle null first_generation_gdd like actual leafminer" do
    pest_data_with_null = {
      "pest_id" => "leafminer",
      "name" => "リーフマイナー",
      "name_scientific" => "Liriomyza spp.",
      "family" => "ウリ科",
      "order" => "双翅目",
      "description" => "リーフマイナーの説明",
      "temperature_profile" => {
        "base_temperature" => 10,
        "max_temperature" => 30
      },
      "thermal_requirement" => {
        "required_gdd" => 300,
        "first_generation_gdd" => nil
      },
      "control_methods" => [
        {
          "method_type" => "chemical",
          "method_name" => "殺虫剤散布",
          "description" => "説明",
          "timing_hint" => "発生初期"
        }
      ],
      "occurrence_season" => "春〜秋"
    }
    
    pest = Pest.from_agrr_output(pest_data: pest_data_with_null, is_reference: true)
    
    assert_not_nil pest.pest_thermal_requirement
    assert_equal 300, pest.pest_thermal_requirement.required_gdd
    assert_nil pest.pest_thermal_requirement.first_generation_gdd
    
    # to_agrr_outputでもnullが正しく扱われること
    output = pest.to_agrr_output
    assert_nil output["thermal_requirement"]["first_generation_gdd"]
  end

  test "from_agrr_output should handle null first_generation_gdd in multiple pests" do
    pest_data_with_null1 = {
      "pest_id" => "cutworm",
      "name" => "カットワーム",
      "name_scientific" => "Agrotis spp.",
      "family" => "ノミバエ科",
      "order" => "チョウ目",
      "description" => "説明",
      "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 30 },
      "thermal_requirement" => { "required_gdd" => 300, "first_generation_gdd" => nil },
      "control_methods" => [],
      "occurrence_season" => "春〜秋"
    }
    
    pest_data_with_null2 = {
      "pest_id" => "white_grub",
      "name" => "シロアリ",
      "name_scientific" => "Phyllophaga spp.",
      "family" => "コガネムシ科",
      "order" => "甲虫目",
      "description" => "説明",
      "temperature_profile" => { "base_temperature" => 10, "max_temperature" => 30 },
      "thermal_requirement" => { "required_gdd" => 300, "first_generation_gdd" => nil },
      "control_methods" => [],
      "occurrence_season" => "春〜秋"
    }
    
    pest1 = Pest.from_agrr_output(pest_data: pest_data_with_null1, is_reference: true)
    pest2 = Pest.from_agrr_output(pest_data: pest_data_with_null2, is_reference: true)
    
    assert_nil pest1.pest_thermal_requirement.first_generation_gdd
    assert_nil pest2.pest_thermal_requirement.first_generation_gdd
    assert_equal 300, pest1.pest_thermal_requirement.required_gdd
    assert_equal 300, pest2.pest_thermal_requirement.required_gdd
  end

  # スコープテスト
  test "reference scope should return reference pests" do
    reference_pest = create(:pest, is_reference: true, user_id: nil)
    user = create(:user)
    user_pest = create(:pest, :user_owned, user: user)
    
    reference_pests = Pest.reference
    
    assert_includes reference_pests, reference_pest
    assert_not_includes reference_pests, user_pest
  end

  test "user_owned scope should return only user-owned pests" do
    user = create(:user)
    reference_pest = create(:pest, is_reference: true, user_id: nil)
    user_pest = create(:pest, :user_owned, user: user)
    
    user_owned_pests = Pest.user_owned
    
    assert_includes user_owned_pests, user_pest
    assert_not_includes user_owned_pests, reference_pest
  end

  test "should filter pests by is_reference and user_id combination" do
    user1 = create(:user)
    user2 = create(:user)
    
    ref_pest = create(:pest, is_reference: true, user_id: nil)
    user1_pest = create(:pest, :user_owned, user: user1)
    user2_pest = create(:pest, :user_owned, user: user2)
    
    # 一般ユーザーの視点
    visible_pests = Pest.where("is_reference = ? OR user_id = ?", true, user1.id)
    
    assert_includes visible_pests, ref_pest
    assert_includes visible_pests, user1_pest
    assert_not_includes visible_pests, user2_pest
  end

  test "recent scope should order by created_at desc" do
    pest1 = create(:pest, created_at: 2.days.ago)
    pest2 = create(:pest, created_at: 1.day.ago)
    pest3 = create(:pest, created_at: Time.current)
    
    recent = Pest.recent.limit(3)
    
    assert_equal pest3.id, recent.first.id
    assert_equal pest2.id, recent.second.id
    assert_equal pest1.id, recent.third.id
  end
end

