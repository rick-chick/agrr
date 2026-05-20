# frozen_string_literal: true

require "test_helper"

class PestTemperatureProfileTest < ActiveSupport::TestCase
  setup do
    @pest = create(:pest)
  end

  test "should validate pest presence" do
    profile = PestTemperatureProfile.new
    assert_not profile.valid?
    assert_includes profile.errors[:pest], "を入力してください"
  end


end
