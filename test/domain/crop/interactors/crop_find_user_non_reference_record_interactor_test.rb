# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropFindUserNonReferenceRecordInteractorTest < DomainLibTestCase
        setup do
          @user = Domain::Shared::Dtos::User.new(id: 9, admin: false, anonymous: false)
          @crop = Entities::CropEntity.new(
            id: 1,
            user_id: 9,
            name: "C",
            variety: nil,
            is_reference: false,
            area_per_unit: nil,
            revenue_per_area: nil,
            region: nil,
            groups: [],
            crop_stages: [],
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )
        end

        test "calls on_success with entity when gateway returns crop" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_by_id, @crop, [ 42 ])

          output = Minitest::Mock.new
          output.expect(:on_success, nil, [ @crop ])

          logger = Minitest::Mock.new
          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, @user, [ @user.id ])

          interactor = CropFindUserNonReferenceRecordInteractor.new(
            output_port: output,
            user_id: @user.id,
            gateway: gateway,
            logger: logger,
            user_lookup: user_lookup
          )

          assert_nil interactor.call(42)

          gateway.verify
          output.verify
          user_lookup.verify
        end

        test "calls on_failure when crop is not editable by user" do
          other_crop = Entities::CropEntity.new(
            id: 99,
            user_id: 1,
            name: "Other",
            variety: nil,
            is_reference: false,
            area_per_unit: nil,
            revenue_per_area: nil,
            region: nil,
            groups: [],
            crop_stages: [],
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )
          gateway = Minitest::Mock.new
          gateway.expect(:find_by_id, other_crop, [ 99 ])

          output = Minitest::Mock.new
          output.expect(:on_failure, nil, [ Domain::Shared::Dtos::Error ])

          logger = Minitest::Mock.new
          logger.expect(:warn, nil, [ String ])
          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, @user, [ @user.id ])

          interactor = CropFindUserNonReferenceRecordInteractor.new(
            output_port: output,
            user_id: @user.id,
            gateway: gateway,
            logger: logger,
            user_lookup: user_lookup
          )

          assert_nil interactor.call(99)

          gateway.verify
          output.verify
          user_lookup.verify
          logger.verify
        end
      end
    end
  end
end
