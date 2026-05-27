# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PlanSaveEnsureUserFieldsInteractorTest < DomainLibTestCase
        def build_translator
          Object.new.tap do |o|
            o.define_singleton_method(:t) do |key, **opts|
              opts.empty? ? key.to_s : "#{key}|#{opts.sort.to_h.inspect}"
            end
          end
        end

        def build_interactor(gateway:, logger: nil, translator: nil)
          PlanSaveEnsureUserFieldsInteractor.new(
            plan_save_field_gateway: gateway,
            logger: logger || CapturingLogger.new,
            translator: translator || build_translator
          )
        end

        def field_datum(name: "区画A", area: 12.5, coordinates: [ 35.0, 139.0 ])
          Dtos::PublicPlanSaveFieldDatum.new(name: name, area: area, coordinates: coordinates)
        end

        def field_snapshot(id:)
          Dtos::PlanSaveFieldSnapshot.new(
            id: id,
            name: "区画",
            area: 1.0,
            farm_id: 5,
            user_id: 1
          )
        end

        test "reuses existing fields and records skips when farm_reused" do
          existing = [
            field_snapshot(id: 10),
            field_snapshot(id: 11)
          ]

          gateway = mock("plan_save_field_gateway")
          gateway.expects(:list_by_farm_id).with(farm_id: 5, user_id: 1).returns(existing)
          gateway.expects(:create).never

          out = build_interactor(gateway: gateway).call(
            Dtos::PlanSaveEnsureUserFieldsInput.new(
              user_id: 1,
              farm_id: 5,
              farm_reused: true,
              field_data: [ field_datum ]
            )
          )

          assert_equal [ 10, 11 ], out.field_ids
          assert_equal [ 10, 11 ], out.skipped_field_ids
        end

        test "creates fields from session when farm is new" do
          gateway = mock("plan_save_field_gateway")
          gateway.expects(:list_by_farm_id).never
          gateway.expects(:create).with(
            farm_id: 5,
            user_id: 1,
            attributes: {
              name: "区画A",
              area: 12.5,
              description: "services.plan_save_service.messages.coordinates|{:lat=>35.0, :lng=>139.0}"
            }
          ).returns(field_snapshot(id: 99))

          out = build_interactor(gateway: gateway).call(
            Dtos::PlanSaveEnsureUserFieldsInput.new(
              user_id: 1,
              farm_id: 5,
              farm_reused: false,
              field_data: [ field_datum ]
            )
          )

          assert_equal [ 99 ], out.field_ids
          assert_empty out.skipped_field_ids
        end

        test "returns empty field_ids when field_data is empty and farm is new" do
          gateway = mock("plan_save_field_gateway")
          gateway.expects(:list_by_farm_id).never
          gateway.expects(:create).never

          out = build_interactor(gateway: gateway).call(
            Dtos::PlanSaveEnsureUserFieldsInput.new(
              user_id: 1,
              farm_id: 5,
              farm_reused: false,
              field_data: []
            )
          )

          assert_empty out.field_ids
          assert_empty out.skipped_field_ids
        end
      end
    end
  end
end
