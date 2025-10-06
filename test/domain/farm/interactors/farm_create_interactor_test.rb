# frozen_string_literal: true

require 'test_helper'

class Domain::Farm::Interactors::FarmCreateInteractorTest < ActiveSupport::TestCase
  def setup
    @gateway = Minitest::Mock.new
    @interactor = Domain::Farm::Interactors::FarmCreateInteractor.new(@gateway)
    @user_id = 1
    @farm_data = {
      user_id: @user_id,
      name: "テスト農場",
      latitude: 35.6762,
      longitude: 139.6503
    }
  end

  test "should create farm successfully" do
    created_farm = Domain::Farm::Entities::FarmEntity.new(@farm_data.merge(id: 1, created_at: Time.current, updated_at: Time.current))
    
    @gateway.expect :create, created_farm, [Hash]
    
    result = @interactor.call(@farm_data)
    
    assert result.success?
    assert_equal created_farm, result.data
    @gateway.verify
  end

  test "should return error when gateway raises exception" do
    @gateway.expect :create, nil do |data|
      raise StandardError, "Database error"
    end
    
    result = @interactor.call(@farm_data)
    
    assert_not result.success?
    assert_equal "Database error", result.error
    @gateway.verify
  end

  test "should return error when validation fails" do
    invalid_data = @farm_data.merge(name: nil)
    
    result = @interactor.call(invalid_data)
    
    assert_not result.success?
    assert_equal "Name is required", result.error
  end
end
