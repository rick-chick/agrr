# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: backdoor is not used by Angular; with AGRR_RUST_API / rust edge it must not reach Rails.
class BackdoorApiContractTest < ContractTestCase
  test "backdoor status is not served by rust edge as Rails would" do
    skip "rails contract only" unless rust_contract?

    response = rust_get(
      "/api/v1/backdoor/status",
      headers: { "X-Backdoor-Token" => "contract-token" }
    )
    assert_includes [404, 501], response.code.to_i,
                    "backdoor must not proxy to Rails (expected 501 api_not_migrated or 404)"
  end
end
