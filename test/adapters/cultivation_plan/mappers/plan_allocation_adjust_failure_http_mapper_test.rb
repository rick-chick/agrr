# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Mappers
      class PlanAllocationAdjustFailureHttpMapperTest < ActiveSupport::TestCase
        Failure = Domain::CultivationPlan::Dtos::PlanAllocationAdjustFailure

        test "maps failure kinds to http status symbols" do
          assert_equal :not_found,
            PlanAllocationAdjustFailureHttpMapper.http_status_for(Failure::KIND_NOT_FOUND)
          assert_equal :bad_request,
            PlanAllocationAdjustFailureHttpMapper.http_status_for(Failure::KIND_CROP_MISSING_GROWTH_STAGES)
          assert_equal :internal_server_error,
            PlanAllocationAdjustFailureHttpMapper.http_status_for(Failure::KIND_UNEXPECTED)
        end
      end
    end
  end
end
