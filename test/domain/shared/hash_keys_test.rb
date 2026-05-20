# frozen_string_literal: true

require "domain_lib_test_helper"

class DomainSharedHashKeysTest < DomainLibTestCase
  test "stringify_keys converts keys to strings at top level only" do
    h = { a: 1, "b" => 2 }
    out = Domain::Shared.stringify_keys(h)
    assert_equal({ "a" => 1, "b" => 2 }, out)
  end

  test "symbolize_keys converts string keys to symbols at top level only" do
    h = { "a" => 1, :b => 2 }
    out = Domain::Shared.symbolize_keys(h)
    assert_equal({ a: 1, b: 2 }, out)
  end

  test "deep_symbolize_keys recurses into nested hashes and arrays" do
    h = { "outer" => { "inner" => [ { "x" => 1 } ] } }
    out = Domain::Shared.deep_symbolize_keys(h)
    assert_equal({ outer: { inner: [ { x: 1 } ] } }, out)
  end

  test "symbolize_keys returns empty hash for nil" do
    assert_equal({}, Domain::Shared.symbolize_keys(nil))
  end

  test "stringify_keys returns empty hash for nil" do
    assert_equal({}, Domain::Shared.stringify_keys(nil))
  end
end
