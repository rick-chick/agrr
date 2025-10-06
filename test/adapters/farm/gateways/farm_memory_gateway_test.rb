# frozen_string_literal: true

require 'test_helper'

class Adapters::Farm::Gateways::FarmMemoryGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Adapters::Farm::Gateways::FarmMemoryGateway.new
    @user = users(:one)
    @farm_data = {
      user_id: @user.id,
      name: "テスト農場",
      latitude: 35.6762,
      longitude: 139.6503
    }
  end

  test "should create farm" do
    farm = @gateway.create(@farm_data)
    
    assert_not_nil farm
    assert_equal "テスト農場", farm.name
    assert_equal @user.id, farm.user_id
    assert farm.is_a?(Domain::Farm::Entities::FarmEntity)
  end

  test "should find farm by id" do
    created_farm = @gateway.create(@farm_data)
    
    found_farm = @gateway.find_by_id(created_farm.id)
    
    assert_not_nil found_farm
    assert_equal created_farm.id, found_farm.id
    assert_equal created_farm.name, found_farm.name
  end

  test "should return nil when farm not found" do
    found_farm = @gateway.find_by_id(999999)
    
    assert_nil found_farm
  end

  test "should find farms by user id" do
    @gateway.create(@farm_data)
    @gateway.create(@farm_data.merge(name: "別の農場"))
    
    farms = @gateway.find_by_user_id(@user.id)
    
    # Should include the newly created farms plus existing fixtures
    assert farms.count >= 2
    assert farms.all? { |farm| farm.is_a?(Domain::Farm::Entities::FarmEntity) }
    # Check that our created farms are included
    farm_names = farms.map(&:name)
    assert_includes farm_names, "テスト農場"
    assert_includes farm_names, "別の農場"
  end

  test "should update farm" do
    created_farm = @gateway.create(@farm_data)
    update_data = { name: "更新された農場" }
    
    updated_farm = @gateway.update(created_farm.id, update_data)
    
    assert_not_nil updated_farm
    assert_equal "更新された農場", updated_farm.name
  end

  test "should delete farm" do
    created_farm = @gateway.create(@farm_data)
    
    result = @gateway.delete(created_farm.id)
    
    assert result
    assert_nil @gateway.find_by_id(created_farm.id)
  end

  test "should check if farm exists" do
    created_farm = @gateway.create(@farm_data)
    
    assert @gateway.exists?(created_farm.id)
    assert_not @gateway.exists?(999999)
  end
end
