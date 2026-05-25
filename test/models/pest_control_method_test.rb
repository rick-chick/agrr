# frozen_string_literal: true

require "test_helper"

class PestControlMethodTest < ActiveSupport::TestCase
  setup do
    @pest = create(:pest)
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

end
