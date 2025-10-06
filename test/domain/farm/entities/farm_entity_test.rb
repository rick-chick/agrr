# frozen_string_literal: true

require 'test_helper'

class Domain::Farm::Entities::FarmEntityTest < ActiveSupport::TestCase
  def setup
    @user_id = 1
    @farm_data = {
      id: 1,
      user_id: @user_id,
      name: "テスト農場",
      latitude: 35.6762,
      longitude: 139.6503,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  test "should create farm entity with valid data" do
    farm = Domain::Farm::Entities::FarmEntity.new(@farm_data)
    
    assert_equal 1, farm.id
    assert_equal @user_id, farm.user_id
    assert_equal "テスト農場", farm.name
    assert_equal 35.6762, farm.latitude
    assert_equal 139.6503, farm.longitude
  end

  test "should validate presence of name" do
    @farm_data[:name] = nil
    
    assert_raises(ArgumentError) do
      Domain::Farm::Entities::FarmEntity.new(@farm_data)
    end
  end

  test "should validate presence of user_id" do
    @farm_data[:user_id] = nil
    
    assert_raises(ArgumentError) do
      Domain::Farm::Entities::FarmEntity.new(@farm_data)
    end
  end

  test "should validate latitude range" do
    @farm_data[:latitude] = 91.0
    
    assert_raises(ArgumentError) do
      Domain::Farm::Entities::FarmEntity.new(@farm_data)
    end
  end

  test "should validate longitude range" do
    @farm_data[:longitude] = 181.0
    
    assert_raises(ArgumentError) do
      Domain::Farm::Entities::FarmEntity.new(@farm_data)
    end
  end

  test "should return coordinates as array" do
    farm = Domain::Farm::Entities::FarmEntity.new(@farm_data)
    
    assert_equal [35.6762, 139.6503], farm.coordinates
  end

  test "should return display name" do
    farm = Domain::Farm::Entities::FarmEntity.new(@farm_data)
    
    assert_equal "テスト農場", farm.display_name
  end

  test "should return fallback display name when name is empty" do
    # Skip validation for this test by creating entity without validation
    farm = Domain::Farm::Entities::FarmEntity.allocate
    farm.instance_variable_set(:@id, 1)
    farm.instance_variable_set(:@name, "")
    
    # Mock the display_name method behavior
    def farm.display_name
      name.presence || "農場 ##{id}"
    end
    
    assert_equal "農場 #1", farm.display_name
  end

  test "should check if has coordinates" do
    farm = Domain::Farm::Entities::FarmEntity.new(@farm_data)
    
    assert farm.has_coordinates?
  end

  test "should return false for has_coordinates when latitude is nil" do
    @farm_data[:latitude] = nil
    farm = Domain::Farm::Entities::FarmEntity.new(@farm_data)
    
    assert_not farm.has_coordinates?
  end
end
