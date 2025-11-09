# frozen_string_literal: true

require "test_helper"

class PestTemperatureProfileTest < ActiveSupport::TestCase
  setup do
    @pest = create(:pest)
  end

  test "should belong to pest" do
    profile = create(:pest_temperature_profile, pest: @pest)
    assert_equal @pest, profile.pest
  end

  test "should validate pest presence" do
    profile = PestTemperatureProfile.new
    assert_not profile.valid?
    assert_includes profile.errors[:pest], "を入力してください"
  end

  test "should destroy when pest is destroyed" do
    profile = create(:pest_temperature_profile, pest: @pest)
    profile_id = profile.id
    
    @pest.destroy
    
    assert_not PestTemperatureProfile.exists?(profile_id)
  end
end








