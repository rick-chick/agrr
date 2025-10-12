require "test_helper"

class Admin::FarmSizesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @farm_size = farm_sizes(:one)
  end

  test "should get index" do
    get admin_farm_sizes_url
    assert_response :success
  end

  test "should get new" do
    get new_admin_farm_size_url
    assert_response :success
  end

  test "should create farm_size" do
    assert_difference("FarmSize.count") do
      post admin_farm_sizes_url, params: { farm_size: { active: @farm_size.active, area_sqm: @farm_size.area_sqm, display_order: @farm_size.display_order, name: @farm_size.name } }
    end

    assert_redirected_to admin_farm_size_url(FarmSize.last)
  end

  test "should show farm_size" do
    get admin_farm_size_url(@farm_size)
    assert_response :success
  end

  test "should get edit" do
    get edit_admin_farm_size_url(@farm_size)
    assert_response :success
  end

  test "should update farm_size" do
    patch admin_farm_size_url(@farm_size), params: { farm_size: { active: @farm_size.active, area_sqm: @farm_size.area_sqm, display_order: @farm_size.display_order, name: @farm_size.name } }
    assert_redirected_to admin_farm_size_url(@farm_size)
  end

  test "should destroy farm_size" do
    assert_difference("FarmSize.count", -1) do
      delete admin_farm_size_url(@farm_size)
    end

    assert_redirected_to admin_farm_sizes_url
  end
end
