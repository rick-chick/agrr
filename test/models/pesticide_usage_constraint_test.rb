# frozen_string_literal: true

require "test_helper"

class PesticideUsageConstraintTest < ActiveSupport::TestCase
  setup do
    @pesticide = create(:pesticide)
  end

  test "should belong to pesticide" do
    constraint = create(:pesticide_usage_constraint, pesticide: @pesticide)
    assert_equal @pesticide, constraint.pesticide
  end

  test "should validate pesticide presence" do
    constraint = PesticideUsageConstraint.new
    assert_not constraint.valid?
    assert_includes constraint.errors[:pesticide], "を入力してください"
  end

  test "should validate max_wind_speed_m_s is greater than or equal to 0" do
    constraint = build(:pesticide_usage_constraint, pesticide: @pesticide, max_wind_speed_m_s: -1.0)
    assert_not constraint.valid?
    assert_includes constraint.errors[:max_wind_speed_m_s], "は0以上の値にしてください"
  end

  test "should validate max_application_count is greater than 0" do
    constraint = build(:pesticide_usage_constraint, pesticide: @pesticide, max_application_count: 0)
    assert_not constraint.valid?
    assert_includes constraint.errors[:max_application_count], "は0より大きい値にしてください"
  end

  test "should validate harvest_interval_days is greater than or equal to 0" do
    constraint = build(:pesticide_usage_constraint, pesticide: @pesticide, harvest_interval_days: -1)
    assert_not constraint.valid?
    assert_includes constraint.errors[:harvest_interval_days], "は0以上の値にしてください"
  end

  test "should validate min_temperature must be less than or equal to max_temperature" do
    constraint = build(:pesticide_usage_constraint, 
                      pesticide: @pesticide, 
                      min_temperature: 40.0, 
                      max_temperature: 35.0)
    assert_not constraint.valid?
    assert_includes constraint.errors[:min_temperature], "must be less than or equal to max_temperature"
  end

  test "should allow min_temperature equal to max_temperature" do
    constraint = build(:pesticide_usage_constraint, 
                      pesticide: @pesticide, 
                      min_temperature: 20.0, 
                      max_temperature: 20.0)
    assert constraint.valid?
  end

  test "should allow nil for optional fields" do
    constraint = build(:pesticide_usage_constraint, 
                      pesticide: @pesticide,
                      min_temperature: nil,
                      max_temperature: nil,
                      max_wind_speed_m_s: nil,
                      max_application_count: nil,
                      harvest_interval_days: nil,
                      other_constraints: nil)
    assert constraint.valid?
  end

  test "should destroy when pesticide is destroyed" do
    constraint = create(:pesticide_usage_constraint, pesticide: @pesticide)
    constraint_id = constraint.id

    @pesticide.destroy

    assert_not PesticideUsageConstraint.exists?(constraint_id)
  end
end








