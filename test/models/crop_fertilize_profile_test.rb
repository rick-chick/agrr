# frozen_string_literal: true

require "test_helper"

class CropFertilizeProfileTest < ActiveSupport::TestCase
  setup do
    @crop = create(:crop, :tomato)
  end

  # バリデーションテスト
  test "should validate crop_id presence" do
    profile = CropFertilizeProfile.new
    assert_not profile.valid?
    assert_includes profile.errors[:crop], "を入力してください"
  end

  # totals計算メソッドのテスト
  test "should calculate total_n from applications" do
    profile = create(:crop_fertilize_profile, crop: @crop)
    create(:crop_fertilize_application, :basal, crop_fertilize_profile: profile)
    create(:crop_fertilize_application, :topdress, crop_fertilize_profile: profile)
    # basal: 6.0 (1 * 6.0), topdress: 12.0 (2 * 6.0)
    assert_equal 18.0, profile.total_n
  end

  test "should calculate total_p from applications" do
    profile = create(:crop_fertilize_profile, crop: @crop)
    create(:crop_fertilize_application, :basal, crop_fertilize_profile: profile)
    create(:crop_fertilize_application, :topdress, crop_fertilize_profile: profile)
    # basal: 2.0 (1 * 2.0), topdress: 3.0 (2 * 1.5)
    assert_equal 5.0, profile.total_p
  end

  test "should calculate total_k from applications" do
    profile = create(:crop_fertilize_profile, crop: @crop)
    create(:crop_fertilize_application, :basal, crop_fertilize_profile: profile)
    create(:crop_fertilize_application, :topdress, crop_fertilize_profile: profile)
    # basal: 3.0 (1 * 3.0), topdress: 9.0 (2 * 4.5)
    assert_equal 12.0, profile.total_k
  end

  # 関連テスト
  test "should belong to crop" do
    profile = create(:crop_fertilize_profile, crop: @crop)
    assert_equal @crop, profile.crop
  end

  test "should have many crop_fertilize_applications" do
    profile = create(:crop_fertilize_profile, :with_applications, crop: @crop)
    assert_equal 2, profile.crop_fertilize_applications.count
  end

  test "should destroy applications when profile is destroyed" do
    profile = create(:crop_fertilize_profile, :with_applications, crop: @crop)
    application_ids = profile.crop_fertilize_applications.pluck(:id)
    
    profile.destroy
    
    application_ids.each do |id|
      assert_not CropFertilizeApplication.exists?(id)
    end
  end

  # sources シリアライズテスト
  test "should serialize sources as JSON array" do
    profile = create(:crop_fertilize_profile, crop: @crop, sources: ["source1", "source2"])
    assert_equal ["source1", "source2"], profile.sources
    assert profile.sources.is_a?(Array)
  end

  test "should handle string sources during migration" do
    profile = CropFertilizeProfile.new(
      crop: @crop,
      sources: "single_source"
    )
    profile.valid?
    assert_equal ["single_source"], profile.sources
  end

  test "should default sources to empty array" do
    profile = CropFertilizeProfile.new(
      crop: @crop
    )
    profile.valid?
    assert_equal [], profile.sources
  end

  # from_agrr_output テスト
  test "should create profile from agrr output" do
    agrr_output = {
      "crop" => { "crop_id" => @crop.id.to_s, "name" => @crop.name },
      "totals" => { "N" => 18.0, "P" => 5.0, "K" => 12.0 },
      "applications" => [
        {
          "type" => "basal",
          "count" => 1,
          "schedule_hint" => "pre-plant",
          "per_application" => { "N" => 6.0, "P" => 2.0, "K" => 3.0 }
        },
        {
          "type" => "topdress",
          "count" => 2,
          "schedule_hint" => "fruiting",
          "per_application" => { "N" => 6.0, "P" => 1.5, "K" => 4.5 }
        }
      ],
      "sources" => ["inmemory"],
      "notes" => "Test notes"
    }

    profile = CropFertilizeProfile.from_agrr_output(crop: @crop, profile_data: agrr_output)

    assert profile.persisted?
    assert_equal @crop, profile.crop
    assert_equal 18.0, profile.total_n
    assert_equal 5.0, profile.total_p
    assert_equal 12.0, profile.total_k
    assert_equal ["inmemory"], profile.sources
    assert_equal "Test notes", profile.notes
    assert_equal 2, profile.crop_fertilize_applications.count

    basal = profile.crop_fertilize_applications.find_by(application_type: "basal")
    assert_equal 1, basal.count
    assert_equal "pre-plant", basal.schedule_hint
    assert_equal 6.0, basal.total_n
    assert_equal 2.0, basal.total_p
    assert_equal 3.0, basal.total_k
    assert_equal 6.0, basal.per_application_n

    topdress = profile.crop_fertilize_applications.find_by(application_type: "topdress")
    assert_equal 2, topdress.count
    assert_equal "fruiting", topdress.schedule_hint
    assert_equal 12.0, topdress.total_n
    assert_equal 3.0, topdress.total_p
    assert_equal 9.0, topdress.total_k
    assert_equal 6.0, topdress.per_application_n
    assert_equal 1.5, topdress.per_application_p
    assert_equal 4.5, topdress.per_application_k
  end

  test "from_agrr_output should handle missing notes" do
    agrr_output = {
      "totals" => { "N" => 18.0, "P" => 5.0, "K" => 12.0 },
      "applications" => [],
      "sources" => []
    }

    profile = CropFertilizeProfile.from_agrr_output(crop: @crop, profile_data: agrr_output)

    assert_nil profile.notes
    assert_equal [], profile.sources
  end

  test "from_agrr_output should handle empty applications array" do
    agrr_output = {
      "totals" => { "N" => 18.0, "P" => 5.0, "K" => 12.0 },
      "applications" => [],
      "sources" => []
    }

    profile = CropFertilizeProfile.from_agrr_output(crop: @crop, profile_data: agrr_output)

    assert_equal 0, profile.crop_fertilize_applications.count
  end

  # to_agrr_output テスト
  test "should convert to agrr output format" do
    profile = create(:crop_fertilize_profile, crop: @crop,
      sources: ["source1", "source2"],
      notes: "Test notes"
    )
    
    basal = create(:crop_fertilize_application, :basal,
      crop_fertilize_profile: profile
    )
    
    topdress = create(:crop_fertilize_application, :topdress,
      crop_fertilize_profile: profile
    )

    output = profile.to_agrr_output

    assert_equal @crop.id.to_s, output["crop"]["crop_id"]
    assert_equal @crop.name, output["crop"]["name"]
    assert_equal 18.0, output["totals"]["N"]
    assert_equal 5.0, output["totals"]["P"]
    assert_equal 12.0, output["totals"]["K"]
    assert_equal ["source1", "source2"], output["sources"]
    assert_equal "Test notes", output["notes"]
    assert_equal 2, output["applications"].count

    basal_output = output["applications"].find { |a| a["type"] == "basal" }
    assert_equal 1, basal_output["count"]
    assert_equal "pre-plant", basal_output["schedule_hint"]
    assert_equal 6.0, basal_output["nutrients"]["N"]
    assert_equal 2.0, basal_output["nutrients"]["P"]
    assert_equal 3.0, basal_output["nutrients"]["K"]
    # basalにもper_applicationがある
    assert_equal 6.0, basal_output["per_application"]["N"]
    assert_equal 2.0, basal_output["per_application"]["P"]
    assert_equal 3.0, basal_output["per_application"]["K"]

    topdress_output = output["applications"].find { |a| a["type"] == "topdress" }
    assert_equal 2, topdress_output["count"]
    assert_equal "fruiting", topdress_output["schedule_hint"]
    assert_equal 12.0, topdress_output["nutrients"]["N"]
    assert_equal 3.0, topdress_output["nutrients"]["P"]
    assert_equal 9.0, topdress_output["nutrients"]["K"]
    assert_equal 6.0, topdress_output["per_application"]["N"]
    assert_equal 1.5, topdress_output["per_application"]["P"]
    assert_equal 4.5, topdress_output["per_application"]["K"]
  end

  test "to_agrr_output should handle nil per_application" do
    profile = create(:crop_fertilize_profile, crop: @crop)
    application = create(:crop_fertilize_application, :topdress_single,
      crop_fertilize_profile: profile,
      per_application_n: nil,
      per_application_p: nil,
      per_application_k: nil
    )

    output = profile.to_agrr_output
    app_output = output["applications"].first
    
    assert_nil app_output["per_application"]
  end

  test "to_agrr_output should handle nil notes" do
    profile = create(:crop_fertilize_profile, crop: @crop, notes: nil)
    output = profile.to_agrr_output
    
    assert_nil output["notes"]
  end

  test "to_agrr_output should handle empty sources" do
    profile = create(:crop_fertilize_profile, crop: @crop, sources: [])
    output = profile.to_agrr_output
    
    assert_equal [], output["sources"]
  end

  test "to_agrr_output should handle nil sources" do
    profile = CropFertilizeProfile.new(
      crop: @crop,
      sources: nil
    )
    profile.save!(validate: false)
    output = profile.to_agrr_output
    
    assert_equal [], output["sources"]
  end

  # スコープテスト
  test "recent scope should order by created_at desc" do
    profile1 = create(:crop_fertilize_profile, crop: @crop, created_at: 2.days.ago)
    profile2 = create(:crop_fertilize_profile, crop: create(:crop), created_at: 1.day.ago)
    profile3 = create(:crop_fertilize_profile, crop: create(:crop), created_at: Time.current)

    recent = CropFertilizeProfile.recent.limit(3)
    assert_equal profile3.id, recent.first.id
    assert_equal profile2.id, recent.second.id
    assert_equal profile1.id, recent.third.id
  end
end

