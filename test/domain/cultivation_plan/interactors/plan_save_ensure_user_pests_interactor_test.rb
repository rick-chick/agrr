# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PlanSaveEnsureUserPestsInteractorTest < DomainLibTestCase
        def build_translator
          Object.new.tap do |o|
            o.define_singleton_method(:t) do |key, **opts|
              opts.empty? ? key.to_s : "#{key}|#{opts.sort.to_h.inspect}"
            end
          end
        end

        def pest_row(pest_id: 100, crop_ids: [ 10 ], name: "害虫A")
          Dtos::PublicPlanSavePestReferenceRow.new(
            reference_pest_id: pest_id,
            name: name,
            linked_reference_crop_ids: crop_ids,
            region: "jp"
          )
        end

        def build_interactor(read_gateway:, user_pest_gateway:, logger: nil, translator: nil)
          PlanSaveEnsureUserPestsInteractor.new(
            read_gateway: read_gateway,
            user_pest_gateway: user_pest_gateway,
            logger: logger || CapturingLogger.new,
            translator: translator || build_translator
          )
        end

        def default_input(crop_map: { 10 => 77 })
          Dtos::PlanSaveEnsureUserPestsInput.new(
            user_id: 1,
            plan_id: 5,
            region: "jp",
            reference_crop_id_to_user_crop_id: crop_map
          )
        end

        test "returns empty output when reference crop map is empty" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_pest_reference_rows).never

          user_pest_gateway = mock("user_pest_gateway")

          out = build_interactor(
            read_gateway: read_gateway,
            user_pest_gateway: user_pest_gateway
          ).call(
            Dtos::PlanSaveEnsureUserPestsInput.new(user_id: 1, plan_id: 5, region: "jp")
          )

          assert_empty out.user_pest_ids
          assert_empty out.skipped_pest_ids
          assert_empty out.reference_pest_id_to_user_pest_id
        end

        test "skips row without crop intersection" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_pest_reference_rows).with(plan_id: 5, region: "jp").returns(
            [ pest_row(pest_id: 100, crop_ids: [ 99 ]) ]
          )

          user_pest_gateway = mock("user_pest_gateway")
          user_pest_gateway.expects(:find_by_user_id_and_source_pest_id).never

          out = build_interactor(
            read_gateway: read_gateway,
            user_pest_gateway: user_pest_gateway
          ).call(default_input)

          assert_empty out.user_pest_ids
        end

        test "second call with same row reuses existing and accumulates skipped_pest_ids" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_pest_reference_rows).twice.returns([ pest_row ])

          user_pest_gateway = mock("user_pest_gateway")
          user_pest_gateway.expects(:find_by_user_id_and_source_pest_id).twice.with(
            user_id: 1,
            source_pest_id: 100
          ).returns(Dtos::PlanSaveUserPestSnapshot.new(id: 55, name: "害虫A"))
          user_pest_gateway.expects(:link_crop_pest).twice.with(crop_id: 77, pest_id: 55)
          user_pest_gateway.expects(:create).never

          interactor = build_interactor(
            read_gateway: read_gateway,
            user_pest_gateway: user_pest_gateway
          )
          input = default_input

          out1 = interactor.call(input)
          out2 = interactor.call(input)

          assert_equal [ 55 ], out1.user_pest_ids
          assert_equal [ 55 ], out2.user_pest_ids
          assert_equal [ 55 ], out1.skipped_pest_ids
          assert_equal [ 55 ], out2.skipped_pest_ids
          assert_equal({ 100 => 55 }, out2.reference_pest_id_to_user_pest_id)
        end

        test "reuses existing user pest and links crops" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_pest_reference_rows).returns([ pest_row ])

          user_pest_gateway = mock("user_pest_gateway")
          user_pest_gateway.expects(:find_by_user_id_and_source_pest_id).with(
            user_id: 1,
            source_pest_id: 100
          ).returns(Dtos::PlanSaveUserPestSnapshot.new(id: 55, name: "害虫A"))
          user_pest_gateway.expects(:link_crop_pest).with(crop_id: 77, pest_id: 55)
          user_pest_gateway.expects(:create).never

          out = build_interactor(
            read_gateway: read_gateway,
            user_pest_gateway: user_pest_gateway
          ).call(default_input)

          assert_equal [ 55 ], out.user_pest_ids
          assert_equal [ 55 ], out.skipped_pest_ids
          assert_equal({ 100 => 55 }, out.reference_pest_id_to_user_pest_id)
        end

        test "creates user pest with child records" do
          row = Dtos::PublicPlanSavePestReferenceRow.new(
            reference_pest_id: 100,
            name: "害虫B",
            linked_reference_crop_ids: [ 10 ],
            region: "jp",
            temperature_profile: Dtos::PublicPlanSavePestTemperatureProfileRow.new(
              base_temperature: 10.0,
              max_temperature: 35.0
            ),
            control_methods: [
              Dtos::PublicPlanSavePestControlMethodRow.new(
                method_type: "chemical",
                method_name: "散布",
                description: "desc",
                timing_hint: "early"
              )
            ]
          )

          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_pest_reference_rows).returns([ row ])

          user_pest_gateway = mock("user_pest_gateway")
          user_pest_gateway.expects(:find_by_user_id_and_source_pest_id).returns(nil)
          user_pest_gateway.expects(:create).with(
            user_id: 1,
            attributes: has_entries(
              name: "害虫B",
              source_pest_id: 100,
              is_reference: false,
              region: "jp"
            )
          ).returns(Dtos::PlanSaveUserPestSnapshot.new(id: 66, name: "害虫B"))
          user_pest_gateway.expects(:create_temperature_profile).with(
            pest_id: 66,
            attributes: { base_temperature: 10.0, max_temperature: 35.0 }
          )
          user_pest_gateway.expects(:create_thermal_requirement).never
          user_pest_gateway.expects(:create_control_method).with(
            pest_id: 66,
            attributes: has_entries(method_type: "chemical", method_name: "散布")
          )
          user_pest_gateway.expects(:link_crop_pest).with(crop_id: 77, pest_id: 66)

          out = build_interactor(
            read_gateway: read_gateway,
            user_pest_gateway: user_pest_gateway
          ).call(default_input)

          assert_equal [ 66 ], out.user_pest_ids
          assert_empty out.skipped_pest_ids
          assert_equal({ 100 => 66 }, out.reference_pest_id_to_user_pest_id)
        end

        test "recovers from uniqueness violation via find" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_pest_reference_rows).returns([ pest_row ])

          user_pest_gateway = mock("user_pest_gateway")
          user_pest_gateway.expects(:find_by_user_id_and_source_pest_id).twice.returns(
            nil,
            Dtos::PlanSaveUserPestSnapshot.new(id: 88, name: "害虫A")
          )
          user_pest_gateway.expects(:create).raises(
            Domain::Shared::Exceptions::RecordInvalid,
            "Pest source_pest_id already taken"
          )
          user_pest_gateway.expects(:link_crop_pest).with(crop_id: 77, pest_id: 88)

          out = build_interactor(
            read_gateway: read_gateway,
            user_pest_gateway: user_pest_gateway
          ).call(default_input)

          assert_equal [ 88 ], out.user_pest_ids
          assert_equal [ 88 ], out.skipped_pest_ids
        end

        test "attributes_for_create uses input region when row region is nil" do
          row = Dtos::PublicPlanSavePestReferenceRow.new(
            reference_pest_id: 100,
            name: "害虫",
            region: nil,
            linked_reference_crop_ids: [ 10 ]
          )

          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_pest_reference_rows).returns([ row ])

          user_pest_gateway = mock("user_pest_gateway")
          user_pest_gateway.expects(:find_by_user_id_and_source_pest_id).returns(nil)
          user_pest_gateway.expects(:create).with(
            user_id: 1,
            attributes: has_entries(region: "jp", source_pest_id: 100)
          ).returns(Dtos::PlanSaveUserPestSnapshot.new(id: 70, name: "害虫"))
          user_pest_gateway.expects(:link_crop_pest).with(crop_id: 77, pest_id: 70)

          build_interactor(
            read_gateway: read_gateway,
            user_pest_gateway: user_pest_gateway
          ).call(default_input)
        end
      end
    end
  end
end
