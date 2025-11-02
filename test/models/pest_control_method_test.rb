# frozen_string_literal: true

require "test_helper"

class PestControlMethodTest < ActiveSupport::TestCase
  setup do
    @pest = create(:pest)
  end

  test "should belong to pest" do
    method = create(:pest_control_method, pest: @pest)
    assert_equal @pest, method.pest
  end

  test "should validate pest presence" do
    method = PestControlMethod.new
    assert_not method.valid?
    assert_includes method.errors[:pest], "を入力してください"
  end

  test "should validate method_type presence" do
    method = PestControlMethod.new(pest: @pest, method_name: "テスト")
    assert_not method.valid?
    assert_includes method.errors[:method_type], "を入力してください"
  end

  test "should validate method_type inclusion" do
    method = PestControlMethod.new(pest: @pest, method_type: "invalid", method_name: "テスト")
    assert_not method.valid?
    assert_includes method.errors[:method_type], "は一覧にありません"
  end

  test "should validate method_name presence" do
    method = PestControlMethod.new(pest: @pest, method_type: "chemical")
    assert_not method.valid?
    assert_includes method.errors[:method_name], "を入力してください"
  end

  test "should accept valid method_types" do
    %w[chemical biological cultural physical].each do |type|
      method = create(:pest_control_method, pest: @pest, method_type: type)
      assert method.valid?
      assert_equal type, method.method_type
    end
  end

  test "chemical scope should return chemical methods" do
    chemical = create(:pest_control_method, :chemical, pest: @pest)
    biological = create(:pest_control_method, :biological, pest: @pest)
    
    chemicals = PestControlMethod.chemical
    
    assert_includes chemicals, chemical
    assert_not_includes chemicals, biological
  end

  test "biological scope should return biological methods" do
    chemical = create(:pest_control_method, :chemical, pest: @pest)
    biological = create(:pest_control_method, :biological, pest: @pest)
    
    biologicals = PestControlMethod.biological
    
    assert_includes biologicals, biological
    assert_not_includes biologicals, chemical
  end

  test "cultural scope should return cultural methods" do
    cultural = create(:pest_control_method, :cultural, pest: @pest)
    physical = create(:pest_control_method, :physical, pest: @pest)
    
    culturals = PestControlMethod.cultural
    
    assert_includes culturals, cultural
    assert_not_includes culturals, physical
  end

  test "physical scope should return physical methods" do
    physical = create(:pest_control_method, :physical, pest: @pest)
    chemical = create(:pest_control_method, :chemical, pest: @pest)
    
    physicals = PestControlMethod.physical
    
    assert_includes physicals, physical
    assert_not_includes physicals, chemical
  end

  test "should destroy when pest is destroyed" do
    method = create(:pest_control_method, pest: @pest)
    method_id = method.id
    
    @pest.destroy
    
    assert_not PestControlMethod.exists?(method_id)
  end
end

