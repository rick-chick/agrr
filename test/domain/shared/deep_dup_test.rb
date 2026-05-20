# frozen_string_literal: true

require "domain_lib_test_helper"

class DomainSharedDeepDupTest < DomainLibTestCase
  test "deep_dup returns distinct nested hashes with equal content" do
    original = { "a" => { "b" => 1 }, :c => [ 1, 2 ] }
    copy = Domain::Shared::DeepDup.deep_dup(original)

    refute_same original, copy
    refute_same original["a"], copy["a"]
    assert_equal original, copy

    copy["a"]["b"] = 99
    assert_equal 1, original["a"]["b"]
  end

  test "deep_dup duplicates strings inside hashes" do
    original = { "name" => "x" }
    copy = Domain::Shared::DeepDup.deep_dup(original)

    refute_same original["name"], copy["name"]
    copy["name"] << "y"
    assert_equal "x", original["name"]
  end

  test "deep_dup preserves symbol keys" do
    original = { foo: { bar: 1 } }
    copy = Domain::Shared::DeepDup.deep_dup(original)

    assert_equal({ foo: { bar: 1 } }, copy)
    refute_same original[:foo], copy[:foo]
  end

  test "deep_dup leaves nil and booleans as identity" do
    assert_nil Domain::Shared::DeepDup.deep_dup(nil)
    assert Domain::Shared::DeepDup.deep_dup(true)
    refute Domain::Shared::DeepDup.deep_dup(false)
  end
end
