# frozen_string_literal: true

require 'test_helper'

class Adapters::Field::Gateways::FieldMemoryGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Adapters::Field::Gateways::FieldMemoryGateway.new
    @user = users(:one)
    @farm = farms(:one)
    @field_data = {
      farm_id: @farm.id,
      user_id: @user.id,
      name: "テスト圃場",
      latitude: 35.6762,
      longitude: 139.6503,
      description: "テスト用の圃場です"
    }
  end

  test "should create field" do
    field = @gateway.create(@field_data)
    
    assert_not_nil field
    assert_equal "テスト圃場", field.name
    assert_equal @farm.id, field.farm_id
    assert_equal @user.id, field.user_id
    assert field.is_a?(Domain::Field::Entities::FieldEntity)
  end

  test "should find field by id" do
    created_field = @gateway.create(@field_data)
    
    found_field = @gateway.find_by_id(created_field.id)
    
    assert_not_nil found_field
    assert_equal created_field.id, found_field.id
    assert_equal created_field.name, found_field.name
  end

  test "should return nil when field not found" do
    found_field = @gateway.find_by_id(999999)
    
    assert_nil found_field
  end

  test "should find fields by farm id" do
    @gateway.create(@field_data)
    @gateway.create(@field_data.merge(name: "別の圃場"))
    
    fields = @gateway.find_by_farm_id(@farm.id)
    
    # Should include the newly created fields plus existing fixtures
    assert fields.count >= 2
    assert fields.all? { |field| field.is_a?(Domain::Field::Entities::FieldEntity) }
    # Check that our created fields are included
    field_names = fields.map(&:name)
    assert_includes field_names, "テスト圃場"
    assert_includes field_names, "別の圃場"
  end

  test "should find fields by user id" do
    @gateway.create(@field_data)
    @gateway.create(@field_data.merge(name: "別の圃場"))
    
    fields = @gateway.find_by_user_id(@user.id)
    
    # Should include the newly created fields plus existing fixtures
    assert fields.count >= 2
    assert fields.all? { |field| field.is_a?(Domain::Field::Entities::FieldEntity) }
    # Check that our created fields are included
    field_names = fields.map(&:name)
    assert_includes field_names, "テスト圃場"
    assert_includes field_names, "別の圃場"
  end

  test "should update field" do
    created_field = @gateway.create(@field_data)
    update_data = { name: "更新された圃場" }
    
    updated_field = @gateway.update(created_field.id, update_data)
    
    assert_not_nil updated_field
    assert_equal "更新された圃場", updated_field.name
  end

  test "should delete field" do
    created_field = @gateway.create(@field_data)
    
    result = @gateway.delete(created_field.id)
    
    assert result
    assert_nil @gateway.find_by_id(created_field.id)
  end

  test "should check if field exists" do
    created_field = @gateway.create(@field_data)
    
    assert @gateway.exists?(created_field.id)
    assert_not @gateway.exists?(999999)
  end
end
