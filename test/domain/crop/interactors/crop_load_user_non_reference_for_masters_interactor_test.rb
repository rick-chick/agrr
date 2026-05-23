# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropLoadUserNonReferenceForMastersInteractorTest < DomainLibTestCase
        setup do
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

        test "calls on_success when gateway returns crop" do
          user = Domain::Shared::Dtos::User.new(id: 9, admin: false, anonymous: false)
          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ 9 ])

          gateway = Minitest::Mock.new
          gateway.expect(:find_by_id, @crop, [ 42 ])

          output = Minitest::Mock.new
          output.expect(:on_success, nil, [ @crop ])

          interactor = CropLoadUserNonReferenceForMastersInteractor.new(
            output_port: output,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup
          )

          assert_nil interactor.call(42)

          user_lookup.verify
          gateway.verify
          output.verify
        end

        test "calls on_not_found when gateway raises RecordNotFound" do
          user = Domain::Shared::Dtos::User.new(id: 9, admin: false, anonymous: false)
          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ 9 ])

          gateway = Minitest::Mock.new
          gateway.expect(:find_by_id, nil) do
            raise Domain::Shared::Exceptions::RecordNotFound, "missing"
          end

          output = Minitest::Mock.new
          output.expect(:on_not_found, nil)

          interactor = CropLoadUserNonReferenceForMastersInteractor.new(
            output_port: output,
            user_id: 9,
            gateway: gateway,
            user_lookup: user_lookup
          )

          assert_nil interactor.call(99)

          user_lookup.verify
          gateway.verify
          output.verify
        end
      end
    end
  end
end
