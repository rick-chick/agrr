# frozen_string_literal: true

require 'test_helper'

class Domain::Field::Interactors::FieldFindInteractorTest < ActiveSupport::TestCase
  def setup
    @gateway = Minitest::Mock.new
    @interactor = Domain::Field::Interactors::FieldFindInteractor.new(@gateway)
    @field_id = 1
    @field_data = {
      id: @field_id,
      farm_id: 1,
      user_id: 1,
      name: "テスト圃場",
      latitude: 35.6762,
      longitude: 139.6503,
      description: "テスト用の圃場です",
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  test "should find field successfully" do
    field = Domain::Field::Entities::FieldEntity.new(@field_data)
    
    @gateway.expect :find_by_id, field, [@field_id]
    
    result = @interactor.call(@field_id)
    
    assert result.success?
    assert_equal field, result.data
    @gateway.verify
  end

  test "should return error when field not found" do
    @gateway.expect :find_by_id, nil, [@field_id]
    
    result = @interactor.call(@field_id)
    
    assert_not result.success?
    assert_equal "Field not found", result.error
    @gateway.verify
  end

  test "should return error when gateway raises exception" do
    @gateway.expect :find_by_id, nil do |id|
      raise StandardError, "Database error"
    end
    
    result = @interactor.call(@field_id)
    
    assert_not result.success?
    assert_equal "Database error", result.error
    @gateway.verify
  end
end
