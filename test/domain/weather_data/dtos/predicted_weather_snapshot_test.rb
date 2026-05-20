# frozen_string_literal: true

require "domain_lib_test_helper"

class PredictedWeatherPayloadTest < DomainLibTestCase
  Dto = Domain::WeatherData::Dtos::PredictedWeatherSnapshot

  test "from_document freezes nested hash" do
    dto = Dto.from_document({ "a" => { "b" => 1 } })
    assert_predicate dto.document, :frozen?
    assert_predicate dto.document["a"], :frozen?
  end

  test "to_storage_hash returns mutable deep dup" do
    dto = Dto.from_document({ "x" => [ { "y" => 2 } ] })
    h = dto.to_storage_hash
    refute_predicate h, :frozen?
    h["x"].first["y"] = 99
    assert_equal 2, dto.document["x"].first["y"]
  end

  test "storage_column_value accepts dto or nil" do
    assert_nil Dto.storage_column_value(nil)
    dto = Dto.from_document({ "k" => "v" })
    assert_equal({ "k" => "v" }, Dto.storage_column_value(dto))
  end
end
