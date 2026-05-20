# frozen_string_literal: true

require "domain_lib_test_helper"

class DomainSharedValidationHelpersTest < DomainLibTestCase
  test "blank? returns true for nil" do
    assert Domain::Shared.blank?(nil)
  end

  test "blank? returns true for false" do
    assert Domain::Shared.blank?(false)
  end

  test "blank? returns false for true" do
    assert_not Domain::Shared.blank?(true)
  end

  test "blank? returns true for empty string" do
    assert Domain::Shared.blank?("")
  end

  test "blank? returns true for whitespace-only string" do
    assert Domain::Shared.blank?("   ")
  end

  test "blank? returns false for non-empty string" do
    assert_not Domain::Shared.blank?("test")
  end

  test "blank? returns true for empty array" do
    assert Domain::Shared.blank?([])
  end

  test "blank? returns true for empty hash" do
    assert Domain::Shared.blank?({})
  end

  test "blank? returns false for non-empty array" do
    assert_not Domain::Shared.blank?([1])
  end

  test "blank? returns false for non-empty hash" do
    assert_not Domain::Shared.blank?({ a: 1 })
  end

  test "blank? returns false for integer" do
    assert_not Domain::Shared.blank?(42)
  end

  test "present? is the inverse of blank?" do
    assert Domain::Shared.present?("test")
    assert_not Domain::Shared.present?(nil)
    assert_not Domain::Shared.present?("")
  end

  test "to_array returns empty array for nil" do
    assert_equal([], Domain::Shared.to_array(nil))
  end

  test "to_array returns the array itself for array input" do
    arr = [1, 2, 3]
    assert_equal(arr, Domain::Shared.to_array(arr))
  end

  test "to_array wraps non-array values in an array" do
    assert_equal([1], Domain::Shared.to_array(1))
    assert_equal(["test"], Domain::Shared.to_array("test"))
  end
end
