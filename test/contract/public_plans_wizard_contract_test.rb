# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: mirrors public plan wizard entry points in
# test/controllers/api/v1/public_plans/wizard_controller_test.rb (smoke: route exists)
class PublicPlansWizardContractTest < ContractTestCase
  test "wizard farms index responds for anonymous session" do
    if rust_contract?
      response = rust_get("/api/v1/public_plans/farms")
      assert_includes [200, 401, 403], response.code.to_i, response.body
    else
      get "/api/v1/public_plans/farms", headers: { "Accept" => "application/json" }
      assert_includes [200, 401, 403], response.status,
                      "wizard farms endpoint must be reachable on contract stack"
    end
  end
end
