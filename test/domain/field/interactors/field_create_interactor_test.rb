# frozen_string_literal: true

require 'test_helper'

class Domain::Field::Interactors::FieldCreateInteractorTest < ActiveSupport::TestCase
  def setup
    @gateway = Minitest::Mock.new
    @interactor = Domain::Field::Interactors::FieldCreateInteractor.new(@gateway)
    @field_data = {
      farm_id: 1,
      user_id: 1,
      name: "テスト圃場",
      latitude: 35.6762,
      longitude: 139.6503,
      description: "テスト用の圃場です"
    }
  end

  test "should create field successfully" do
    created_field = Domain::Field::Entities::FieldEntity.new(@field_data.merge(id: 1, created_at: Time.current, updated_at: Time.current))
    
    @gateway.expect :create, created_field, [Hash]
    
    result = @interactor.call(@field_data)
    
    assert result.success?
    assert_equal created_field, result.data
    @gateway.verify
  end

  test "should return error when gateway raises exception" do
    @gateway.expect :create, nil do |data|
      raise StandardError, "Database error"
    end
    
    result = @interactor.call(@field_data)
    
    assert_not result.success?
    assert_equal "Database error", result.error
    @gateway.verify
  end

  test "should return error when validation fails" do
    invalid_data = @field_data.merge(name: nil)
    
    result = @interactor.call(invalid_data)
    
    assert_not result.success?
    assert_equal "Name is required", result.error
  end
end
