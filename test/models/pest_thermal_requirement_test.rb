# frozen_string_literal: true

require "test_helper"

class PestThermalRequirementTest < ActiveSupport::TestCase
  setup do
    @pest = create(:pest)
  end

  test "should validate pest presence" do
    requirement = PestThermalRequirement.new
    assert_not requirement.valid?
    assert_includes requirement.errors[:pest], "を入力してください"
  end

  test "should allow null first_generation_gdd" do
    requirement = create(:pest_thermal_requirement, pest: @pest, first_generation_gdd: nil)
    assert requirement.valid?
    assert_nil requirement.first_generation_gdd
  end


end
