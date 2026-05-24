# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Policies
      class CropMastersCropEditAccessTest < DomainLibTestCase
        TestUser = Struct.new(:id, :admin?, keyword_init: true)

        FailurePort = Struct.new(:calls) do
          def initialize
            super([])
          end

          def on_failure(failure)
            calls << failure
          end
        end

        setup do
          @fixed_at = Time.utc(2026, 1, 15, 12, 0, 0).freeze
          @user = TestUser.new(id: 1, admin?: false)
          @access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(@user)
          @output_port = FailurePort.new
          @failure = Domain::Crop::Dtos::MastersCropTaskTemplateMastersFailure.new(reason: :crop_not_found)
        end

        def crop_entity(user_id:)
          Entities::CropEntity.new(
            id: 2,
            user_id: user_id,
            name: "Foo",
            variety: nil,
            is_reference: false,
            area_per_unit: nil,
            revenue_per_area: nil,
            region: nil,
            groups: [],
            crop_stages: [],
            created_at: @fixed_at,
            updated_at: @fixed_at
          )
        end

        test "assert_edit_or_on_failure returns true when edit is allowed" do
          assert CropMastersCropEditAccess.assert_edit_or_on_failure(
            access_filter: @access_filter,
            crop_entity: crop_entity(user_id: 1),
            output_port: @output_port,
            failure: @failure,
          )
        end

        test "assert_edit_or_on_failure calls on_failure when edit is denied" do
          assert_not CropMastersCropEditAccess.assert_edit_or_on_failure(
            access_filter: @access_filter,
            crop_entity: crop_entity(user_id: 99),
            output_port: @output_port,
            failure: @failure
          )
          assert_equal [@failure], @output_port.calls
        end
      end
    end
  end
end
