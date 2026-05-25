# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Dtos
      class PublicPlanSaveSessionDataTest < DomainLibTestCase
        test "from_session_hash builds dto from plain hash" do
          dto = PublicPlanSaveSessionData.from_session_hash(
            "plan_id" => 99,
            "farm_id" => 5,
            "crop_ids" => [],
            "field_data" => []
          )

          assert_equal 99, dto.plan_id
          assert_equal 5, dto.farm_id
        end
      end
    end
  end
end
