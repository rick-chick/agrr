# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: agrr-server exposes /cable (not Rails ActionCable fallback).
class OptimizationChannelRustContractTest < ContractTestCase
  test "cable route is not global api_not_migrated 501" do

    response = rust_get("/cable")
    refute_equal 501, response.code.to_i,
                 "cable must be handled by agrr-server, not global 501 fallback"
  end
end
