# frozen_string_literal: true

require 'test_helper'

class Domain::Farm::Interactors::FarmUpdateInteractorTest < ActiveSupport::TestCase
  def setup
    @gateway = Minitest::Mock.new
    @interactor = Domain::Farm::Interactors::FarmUpdateInteractor.new(@gateway)
    @farm_id = 1
    @update_data = {
      name: "更新された農場",
      latitude: 36.6762,
      longitude: 140.6503
    }
    @existing_farm = Domain::Farm::Entities::FarmEntity.new({
      id: @farm_id,
      user_id: 1,
      name: "元の農場",
      latitude: 35.6762,
      longitude: 139.6503,
      created_at: Time.current,
      updated_at: Time.current
    })
  end

  test "should update farm successfully" do
    updated_attributes = {
      id: @existing_farm.id,
      user_id: @existing_farm.user_id,
      name: @update_data[:name],
      latitude: @update_data[:latitude],
      longitude: @update_data[:longitude],
      created_at: @existing_farm.created_at,
      updated_at: Time.current
    }
    updated_farm = Domain::Farm::Entities::FarmEntity.new(updated_attributes)
    
    @gateway.expect :exists?, true, [@farm_id]
    @gateway.expect :update, updated_farm, [@farm_id, Hash]
    
    result = @interactor.call(@farm_id, @update_data)
    
    assert result.success?
    assert_equal updated_farm, result.data
    @gateway.verify
  end

  test "should return error when farm does not exist" do
    @gateway.expect :exists?, false, [@farm_id]
    
    result = @interactor.call(@farm_id, @update_data)
    
    assert_not result.success?
    assert_equal "Farm not found", result.error
    @gateway.verify
  end

  test "should return error when gateway raises exception" do
    @gateway.expect :exists?, true, [@farm_id]
    @gateway.expect :update, nil do |id, data|
      raise StandardError, "Database error"
    end
    
    result = @interactor.call(@farm_id, @update_data)
    
    assert_not result.success?
    assert_equal "Database error", result.error
    @gateway.verify
  end

  test "should return error when validation fails" do
    invalid_data = @update_data.merge(latitude: 91.0)
    
    @gateway.expect :exists?, true, [@farm_id]
    
    result = @interactor.call(@farm_id, invalid_data)
    
    assert_not result.success?
    assert_equal "Latitude must be between -90 and 90", result.error
    @gateway.verify
  end
end
