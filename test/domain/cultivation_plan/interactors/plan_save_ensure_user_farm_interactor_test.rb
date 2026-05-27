# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PlanSaveEnsureUserFarmInteractorTest < DomainLibTestCase
        def build_translator
          Object.new.tap do |o|
            o.define_singleton_method(:t) do |key, **opts|
              opts.empty? ? key.to_s : "#{key}|#{opts.sort.to_h.inspect}"
            end
          end
        end

        def build_clock(fixed_utc)
          Object.new.tap do |o|
            o.define_singleton_method(:now) { fixed_utc }
          end
        end

        def build_interactor(gateway:, logger: nil, translator: nil, clock: nil)
          PlanSaveEnsureUserFarmInteractor.new(
            plan_save_farm_gateway: gateway,
            logger: logger || CapturingLogger.new,
            translator: translator || build_translator,
            clock: clock || build_clock(Time.utc(2026, 5, 25, 12, 34, 56))
          )
        end

        def reference_farm_snapshot
          Dtos::PlanSaveReferenceFarmSnapshot.new(
            id: 10,
            name: "参照農場",
            latitude: 35.0,
            longitude: 135.0,
            region: "kanto",
            weather_location_id: 3
          )
        end

        def user_farm_snapshot(id:, name:, region: "kanto")
          Dtos::PlanSaveUserFarmSnapshot.new(id: id, name: name, region: region)
        end

        test "reuses existing user farm linked to reference" do
          ref = reference_farm_snapshot
          existing = user_farm_snapshot(id: 77, name: "参照農場 (既存)")

          gateway = mock("plan_save_farm_gateway")
          gateway.expects(:find_reference_farm).with(farm_id: 10).returns(ref)
          gateway.expects(:find_user_farm_by_source).with(user_id: 1, source_farm_id: 10).returns(existing)
          gateway.expects(:count_non_reference_farms).never
          gateway.expects(:create_user_farm_from_reference).never

          interactor = build_interactor(gateway: gateway)
          out = interactor.call(Dtos::PlanSaveEnsureUserFarmInput.new(user_id: 1, reference_farm_id: 10))

          assert_equal 77, out.farm_id
          assert out.farm_reused
          assert_equal "kanto", out.farm_region
        end

        test "creates user farm from reference when none exists" do
          ref = reference_farm_snapshot
          created = user_farm_snapshot(id: 88, name: "参照農場 (コピー 20260525_123456)")

          gateway = mock("plan_save_farm_gateway")
          gateway.expects(:find_reference_farm).with(farm_id: 10).returns(ref)
          gateway.expects(:find_user_farm_by_source).with(user_id: 1, source_farm_id: 10).returns(nil)
          gateway.expects(:count_non_reference_farms).with(user_id: 1).returns(2)
          gateway.expects(:create_user_farm_from_reference).with(
            user_id: 1,
            reference_farm_id: 10,
            copy_name_suffix: "20260525_123456"
          ).returns(created)

          interactor = build_interactor(gateway: gateway)
          out = interactor.call(Dtos::PlanSaveEnsureUserFarmInput.new(user_id: 1, reference_farm_id: 10))

          assert_equal 88, out.farm_id
          assert_not out.farm_reused
          assert_equal "kanto", out.farm_region
        end

        test "raises RecordInvalid when farm create limit exceeded" do
          ref = reference_farm_snapshot

          gateway = mock("plan_save_farm_gateway")
          gateway.expects(:find_reference_farm).with(farm_id: 10).returns(ref)
          gateway.expects(:find_user_farm_by_source).with(user_id: 1, source_farm_id: 10).returns(nil)
          gateway.expects(:count_non_reference_farms).with(user_id: 1).returns(4)
          gateway.expects(:create_user_farm_from_reference).never

          interactor = build_interactor(gateway: gateway)

          err = assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
            interactor.call(Dtos::PlanSaveEnsureUserFarmInput.new(user_id: 1, reference_farm_id: 10))
          end
          assert_equal "activerecord.errors.models.farm.attributes.user.farm_limit_exceeded", err.message
        end

        test "raises RecordNotFound when reference farm is missing" do
          gateway = mock("plan_save_farm_gateway")
          gateway.expects(:find_reference_farm).with(farm_id: 10).returns(nil)
          gateway.expects(:find_user_farm_by_source).never

          interactor = build_interactor(gateway: gateway)

          err = assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
            interactor.call(Dtos::PlanSaveEnsureUserFarmInput.new(user_id: 1, reference_farm_id: 10))
          end
          assert_equal(
            "services.plan_save_service.errors.farm_not_found|{:farm_id=>10}",
            err.message
          )
        end
      end
    end
  end
end
