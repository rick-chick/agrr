# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PlanSaveEnsureUserPesticidesInteractorTest < DomainLibTestCase
        def build_translator
          Object.new.tap do |o|
            o.define_singleton_method(:t) do |key, **opts|
              opts.empty? ? key.to_s : "#{key}|#{opts.sort.to_h.inspect}"
            end
          end
        end

        def pesticide_wire(
          pesticide_id: 300,
          crop_id: 10,
          pest_id: 20,
          name: "農薬A",
          with_constraint: false,
          with_detail: false
        )
          usage_constraint = if with_constraint
                               Dtos::PublicPlanSavePesticideUsageConstraintRow.new(
                                 min_temperature: 5.0,
                                 max_temperature: 35.0,
                                 max_wind_speed_m_s: nil,
                                 max_application_count: nil,
                                 harvest_interval_days: nil,
                                 other_constraints: nil
                               )
                             end
          application_detail = if with_detail
                                   Dtos::PublicPlanSavePesticideApplicationDetailRow.new(
                                     dilution_ratio: "1000倍",
                                     amount_per_m2: 0.5,
                                     amount_unit: nil,
                                     application_method: nil
                                   )
                                 end

          Dtos::PublicPlanSavePesticideReferenceRow.new(
            reference_pesticide_id: pesticide_id,
            reference_crop_id: crop_id,
            reference_pest_id: pest_id,
            name: name,
            active_ingredient: "成分",
            description: nil,
            region: "jp",
            usage_constraint: usage_constraint,
            application_detail: application_detail
          )
        end

        def snapshot(id:, name: "農薬A")
          Dtos::PlanSaveUserPesticideSnapshot.new(id: id, name: name)
        end

        def build_interactor(read_gateway:, user_pesticide_gateway:, logger: nil, translator: nil)
          PlanSaveEnsureUserPesticidesInteractor.new(
            read_gateway: read_gateway,
            user_pesticide_gateway: user_pesticide_gateway,
            logger: logger || CapturingLogger.new,
            translator: translator || build_translator
          )
        end

        def default_input(crop_map: { 10 => 101 }, pest_map: { 20 => 201 })
          Dtos::PlanSaveEnsureUserPesticidesInput.new(
            user_id: 1,
            region: "jp",
            reference_crop_id_to_user_crop_id: crop_map,
            reference_pest_id_to_user_pest_id: pest_map
          )
        end

        test "creates user pesticide when crop and pest maps resolve" do
          row = pesticide_wire
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_pesticide_reference_rows).with(region: "jp").returns([ row ])

          user_pesticide_gateway = mock("user_pesticide_gateway")
          user_pesticide_gateway.expects(:find_by_user_id_and_source_pesticide_id).with(
            user_id: 1,
            source_pesticide_id: 300
          ).returns(nil)
          user_pesticide_gateway.expects(:create).with(
            user_id: 1,
            attributes: anything,
            usage_constraint_attributes: nil,
            application_detail_attributes: nil
          ).once.returns(snapshot(id: 88, name: "農薬A"))

          out = build_interactor(
            read_gateway: read_gateway,
            user_pesticide_gateway: user_pesticide_gateway
          ).call(default_input)

          assert_equal [ 88 ], out.user_pesticide_ids
          assert_empty out.skipped_pesticide_ids
        end

        test "logs pesticide_created on new create" do
          row = pesticide_wire
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_pesticide_reference_rows).returns([ row ])

          user_pesticide_gateway = mock("user_pesticide_gateway")
          user_pesticide_gateway.expects(:find_by_user_id_and_source_pesticide_id).returns(nil)
          user_pesticide_gateway.expects(:create).returns(snapshot(id: 55, name: "農薬A"))

          logger = CapturingLogger.new
          build_interactor(
            read_gateway: read_gateway,
            user_pesticide_gateway: user_pesticide_gateway,
            logger: logger
          ).call(default_input)

          assert logger.entries.any? { |level, m| level == :info && m.include?("pesticide_created") }
        end

        test "reuses existing user pesticide and records skip in both id arrays" do
          row = pesticide_wire
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_pesticide_reference_rows).returns([ row ])

          user_pesticide_gateway = mock("user_pesticide_gateway")
          user_pesticide_gateway.expects(:find_by_user_id_and_source_pesticide_id).with(
            user_id: 1,
            source_pesticide_id: 300
          ).returns(snapshot(id: 77, name: "既存農薬"))
          user_pesticide_gateway.expects(:create).never

          out = build_interactor(
            read_gateway: read_gateway,
            user_pesticide_gateway: user_pesticide_gateway
          ).call(default_input)

          assert_equal [ 77 ], out.user_pesticide_ids
          assert_equal [ 77 ], out.skipped_pesticide_ids
        end

        test "skips row when crop or pest map is missing" do
          row = pesticide_wire(crop_id: 99, pest_id: 88)
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_pesticide_reference_rows).returns([ row ])

          user_pesticide_gateway = mock("user_pesticide_gateway")
          user_pesticide_gateway.expects(:find_by_user_id_and_source_pesticide_id).never
          user_pesticide_gateway.expects(:create).never

          logger = CapturingLogger.new
          out = build_interactor(
            read_gateway: read_gateway,
            user_pesticide_gateway: user_pesticide_gateway,
            logger: logger
          ).call(default_input)

          assert_empty out.user_pesticide_ids
          assert_empty out.skipped_pesticide_ids
          assert logger.entries.any? { |level, m| level == :warn && m.include?("missing crop/pest mapping") }
        end

      end
    end
  end
end
