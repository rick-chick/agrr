# frozen_string_literal: true

require "test_helper"

class FieldRegionTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @farm = farms(:one)
  end

  # 基本的なCRUD操作

  test "should create field without region" do
    field = Field.create!(
      farm: @farm,
      user: @user,
      name: "Global Field"
    )
    
    assert_nil field.region
    field.reload
    assert_nil field.region
  end

  test "should create field with jp region" do
    field = Field.create!(
      farm: @farm,
      user: @user,
      name: "Japanese Field",
      region: "jp"
    )
    
    assert_equal "jp", field.region
    field.reload
    assert_equal "jp", field.region
  end

  test "should create field with us region" do
    field = Field.create!(
      farm: @farm,
      user: @user,
      name: "US Field",
      region: "us"
    )
    
    assert_equal "us", field.region
    field.reload
    assert_equal "us", field.region
  end

  test "should update field region from nil to jp" do
    field = Field.create!(
      farm: @farm,
      user: @user,
      name: "Field to Update"
    )
    
    assert_nil field.region
    
    field.update!(region: "jp")
    assert_equal "jp", field.region
    
    field.reload
    assert_equal "jp", field.region
  end

  test "should update field region from jp to us" do
    field = Field.create!(
      farm: @farm,
      user: @user,
      name: "Field to Change",
      region: "jp"
    )
    
    field.update!(region: "us")
    assert_equal "us", field.region
  end

  test "should clear field region" do
    field = Field.create!(
      farm: @farm,
      user: @user,
      name: "Field to Clear",
      region: "jp"
    )
    
    field.update!(region: nil)
    assert_nil field.region
  end

  # by_regionスコープのテスト

  test "by_region scope should return only fields with specified region" do
    field_jp1 = Field.create!(farm: @farm, user: @user, name: "JP Field 1", region: "jp")
    field_jp2 = Field.create!(farm: @farm, user: @user, name: "JP Field 2", region: "jp")
    field_us = Field.create!(farm: @farm, user: @user, name: "US Field", region: "us")
    field_global = Field.create!(farm: @farm, user: @user, name: "Global Field")
    
    jp_fields = Field.by_region("jp")
    
    assert_equal 2, jp_fields.count
    assert_includes jp_fields, field_jp1
    assert_includes jp_fields, field_jp2
    assert_not_includes jp_fields, field_us
    assert_not_includes jp_fields, field_global
  end

  test "by_region scope should not include nil region fields" do
    Field.create!(farm: @farm, user: @user, name: "JP Field", region: "jp")
    Field.create!(farm: @farm, user: @user, name: "Global Field 1")
    Field.create!(farm: @farm, user: @user, name: "Global Field 2")
    
    jp_fields = Field.by_region("jp")
    
    assert_equal 1, jp_fields.count
  end

  test "by_region scope should return empty when no matching region" do
    Field.create!(farm: @farm, user: @user, name: "JP Field", region: "jp")
    Field.create!(farm: @farm, user: @user, name: "US Field", region: "us")
    
    eu_fields = Field.by_region("eu")
    
    assert_equal 0, eu_fields.count
    assert_empty eu_fields
  end

  test "by_region scope should work with other scopes" do
    user2 = User.create!(
      email: "user2_region@example.com",
      name: "User 2",
      google_id: "google_#{SecureRandom.hex(8)}"
    )
    
    field1 = Field.create!(farm: @farm, user: @user, name: "User1 JP Field", region: "jp")
    field2 = Field.create!(farm: @farm, user: user2, name: "User2 JP Field", region: "jp")
    Field.create!(farm: @farm, user: @user, name: "User1 US Field", region: "us")
    
    user1_jp_fields = Field.by_user(@user).by_region("jp")
    
    assert_equal 1, user1_jp_fields.count
    assert_includes user1_jp_fields, field1
    assert_not_includes user1_jp_fields, field2
  end

  # 実際の使用シナリオ

  test "should support providing region-specific default fields" do
    # 日本用のデフォルト圃場
    jp_default_fields = [
      Field.create!(farm: @farm, user: nil, name: "水田A", region: "jp", area: 1000),
      Field.create!(farm: @farm, user: nil, name: "畑B", region: "jp", area: 500)
    ]
    
    # アメリカ用のデフォルト圃場
    us_default_fields = [
      Field.create!(farm: @farm, user: nil, name: "Field A", region: "us", area: 5000),
      Field.create!(farm: @farm, user: nil, name: "Field B", region: "us", area: 3000)
    ]
    
    # 地域別に取得
    jp_fields = Field.by_region("jp").anonymous
    us_fields = Field.by_region("us").anonymous
    
    assert_equal 2, jp_fields.count
    assert_equal 2, us_fields.count
    
    # 日本のフィールドには日本のデータのみ
    jp_fields.each do |field|
      assert_equal "jp", field.region
      assert_nil field.user_id
    end
    
    # アメリカのフィールドにはアメリカのデータのみ
    us_fields.each do |field|
      assert_equal "us", field.region
      assert_nil field.user_id
    end
  end

  test "should allow same field name in different regions" do
    field_jp = Field.create!(
      farm: @farm,
      user: @user,
      name: "Default Field",
      region: "jp"
    )
    
    field_us = Field.create!(
      farm: @farm,
      user: @user,
      name: "Default Field",
      region: "us"
    )
    
    assert field_jp.valid?
    assert field_us.valid?
    assert_not_equal field_jp.id, field_us.id
  end
end

