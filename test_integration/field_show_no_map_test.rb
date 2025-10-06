# frozen_string_literal: true

require "test_helper"

class FieldShowNoMapTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @farm = Farm.create!(
      user: @user,
      name: "テスト農場",
      latitude: 35.6812,
      longitude: 139.7671
    )
    @field = Field.create!(
      farm: @farm,
      user: @user,
      name: "テスト圃場",
      latitude: 35.6812,
      longitude: 139.7671
    )
  end

  test "field show page should not raise NoMethodError for has_coordinates?" do
    get farm_field_path(@farm, @field)
    assert_response :success
    assert_select "h1", text: @field.display_name
  end

  test "field with coordinates should display coordinates" do
    get farm_field_path(@farm, @field)
    assert_response :success
    assert_select ".field-coordinates", text: /35.6812.*139.7671/
  end

  test "field without coordinates should display no coordinates message" do
    @field.update!(latitude: nil, longitude: nil)
    get farm_field_path(@farm, @field)
    assert_response :success
    assert_select ".field-coordinates", text: /位置情報なし/
  end
end
