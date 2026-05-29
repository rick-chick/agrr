# frozen_string_literal: true

require "test_helper"

# R4: public plan wizard + workbench read endpoints on strangler stack (agrr-server).
class PublicPlansApiContractTest < ActionDispatch::IntegrationTest
  test "wizard farms index responds" do
    get "/api/v1/public_plans/farms", params: { region: "jp" },
        headers: { "Accept" => "application/json" }

    assert_includes [200, 501], response.status,
                    "farms must be routed to rust or explicit not-migrated"
    return if response.status == 501

    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end

  test "wizard farm_sizes index responds with catalog entry" do
    get "/api/v1/public_plans/farm_sizes", headers: { "Accept" => "application/json" }

    assert_includes [200, 501], response.status
    return if response.status == 501

    json = JSON.parse(response.body)
    assert json.is_a?(Array)
    home = json.find { |s| s["id"] == "home_garden" }
    assert home, "expected home_garden in farm_sizes catalog"
    assert_equal 30, home["area_sqm"]
  end

  test "wizard crops index responds for reference farm when data exists" do
    farm = Farm.where(is_reference: true).first
    skip "no reference farm in contract DB" unless farm

    get "/api/v1/public_plans/crops",
        params: { farm_id: farm.id },
        headers: { "Accept" => "application/json" }

    assert_includes [200, 404, 501], response.status
  end

  test "public cultivation plan data route is reachable" do
    plan = CultivationPlan.where(plan_type: "public").order(id: :desc).first
    skip "no public cultivation plan in contract DB" unless plan

    get "/api/v1/public_plans/cultivation_plans/#{plan.id}/data",
        headers: { "Accept" => "application/json" }

    assert_includes [200, 404, 501], response.status
  end
end
