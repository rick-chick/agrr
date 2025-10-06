# frozen_string_literal: true

require 'test_helper'

class Domain::Farm::Interactors::FarmFindInteractorTest < ActiveSupport::TestCase
  def setup
    @gateway = Minitest::Mock.new
    @interactor = Domain::Farm::Interactors::FarmFindInteractor.new(@gateway)
    @farm_id = 1
    @farm_data = {
      id: @farm_id,
      user_id: 1,
      name: "テスト農場",
      latitude: 35.6762,
      longitude: 139.6503,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  test "should find farm successfully" do
    farm = Domain::Farm::Entities::FarmEntity.new(@farm_data)
    
    @gateway.expect :find_by_id, farm, [@farm_id]
    
    result = @interactor.call(@farm_id)
    
    assert result.success?
    assert_equal farm, result.data
    @gateway.verify
  end

  test "should return error when farm not found" do
    @gateway.expect :find_by_id, nil, [@farm_id]
    
    result = @interactor.call(@farm_id)
    
    assert_not result.success?
    assert_equal "Farm not found", result.error
    @gateway.verify
  end

  test "should return error when gateway raises exception" do
    @gateway.expect :find_by_id, nil do |id|
      raise StandardError, "Database error"
    end
    
    result = @interactor.call(@farm_id)
    
    assert_not result.success?
    assert_equal "Database error", result.error
    @gateway.verify
  end
end
