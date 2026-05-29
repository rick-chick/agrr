# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PlanSaveEnsureUserCropsInteractorTest < DomainLibTestCase
        def build_translator
          Object.new.tap do |o|
            o.define_singleton_method(:t) do |key, **opts|
              opts.empty? ? key.to_s : "#{key}|#{opts.sort.to_h.inspect}"
            end
          end
        end

        def reference_row_wire(cpc_id: 1, crop_id: 10, name: "トマト")
          Dtos::PublicPlanSaveCropReferenceRow.new(
            cultivation_plan_crop_id: cpc_id,
            reference_crop_id: crop_id,
            name: name,
            variety: "v",
            area_per_unit: 0.2,
            revenue_per_area: 1000.0,
            groups: [ "g1" ],
            region: "jp"
          )
        end

        def build_interactor(read_gateway:, user_crop_gateway:, crop_gateway:, logger: nil, translator: nil)
          PlanSaveEnsureUserCropsInteractor.new(
            read_gateway: read_gateway,
            user_crop_gateway: user_crop_gateway,
            crop_gateway: crop_gateway,
            logger: logger || CapturingLogger.new,
            translator: translator || build_translator
          )
        end

        test "reuses existing user crop and does not enqueue stage copy" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_crop_reference_rows).with(plan_id: 5).returns([ reference_row_wire ])

          user_crop_gateway = mock("user_crop_gateway")
          user_crop_gateway.expects(:find_by_user_id_and_source_crop_id).with(
            user_id: 1,
            source_crop_id: 10
          ).returns(Dtos::PlanSaveUserCropSnapshot.new(id: 77))
          user_crop_gateway.expects(:create).never

          crop_gateway = mock("crop_gateway")
          crop_gateway.expects(:count_user_owned_non_reference_crops).never

          out = build_interactor(
            read_gateway: read_gateway,
            user_crop_gateway: user_crop_gateway,
            crop_gateway: crop_gateway
          ).call(Dtos::PlanSaveEnsureUserCropsInput.new(user_id: 1, plan_id: 5))

          assert_equal [ 77 ], out.user_crop_ids
          assert_equal [ 77 ], out.skipped_crop_ids
          assert_equal({ 10 => 77 }, out.reference_crop_id_to_user_crop_id)
          assert_equal({ 1 => 77 }, out.ref_cpc_id_to_user_crop_id)
          assert_empty out.stage_copy_pairs
        end

        test "creates user crop and returns stage copy pair" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_crop_reference_rows).with(plan_id: 5).returns([ reference_row_wire ])

          user_crop_gateway = mock("user_crop_gateway")
          user_crop_gateway.expects(:find_by_user_id_and_source_crop_id).returns(nil)
          user_crop_gateway.expects(:create).with(
            user_id: 1,
            attributes: has_entries(
              name: "トマト",
              source_crop_id: 10,
              is_reference: false
            )
          ).returns(Dtos::PlanSaveUserCropSnapshot.new(id: 88))

          crop_gateway = mock("crop_gateway")
          crop_gateway.expects(:count_user_owned_non_reference_crops).with(user_id: 1).returns(2)

          out = build_interactor(
            read_gateway: read_gateway,
            user_crop_gateway: user_crop_gateway,
            crop_gateway: crop_gateway
          ).call(Dtos::PlanSaveEnsureUserCropsInput.new(user_id: 1, plan_id: 5))

          assert_equal [ 88 ], out.user_crop_ids
          assert_empty out.skipped_crop_ids
          assert_equal 1, out.stage_copy_pairs.size
          assert_equal 10, out.stage_copy_pairs.first.reference_crop_id
          assert_equal 88, out.stage_copy_pairs.first.new_crop_id
          assert_equal %w[g1 トマト], out.reference_crop_groups.sort
        end

        test "creates user crop for each list_crop_reference_rows entry regardless of crop region" do
          us_row = Dtos::PublicPlanSaveCropReferenceRow.new(
            cultivation_plan_crop_id: 2,
            reference_crop_id: 99,
            name: "US参照作物",
            variety: "USV",
            area_per_unit: 0.5,
            revenue_per_area: 7000.0,
            groups: [],
            region: "us"
          )

          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_crop_reference_rows).with(plan_id: 5).returns([ us_row ])

          user_crop_gateway = mock("user_crop_gateway")
          user_crop_gateway.expects(:find_by_user_id_and_source_crop_id).with(
            user_id: 1,
            source_crop_id: 99
          ).returns(nil)
          user_crop_gateway.expects(:create).with(
            user_id: 1,
            attributes: has_entries(
              name: "US参照作物",
              source_crop_id: 99,
              region: "us",
              is_reference: false
            )
          ).returns(Dtos::PlanSaveUserCropSnapshot.new(id: 55))

          crop_gateway = mock("crop_gateway")
          crop_gateway.expects(:count_user_owned_non_reference_crops).with(user_id: 1).returns(0)

          out = build_interactor(
            read_gateway: read_gateway,
            user_crop_gateway: user_crop_gateway,
            crop_gateway: crop_gateway
          ).call(Dtos::PlanSaveEnsureUserCropsInput.new(user_id: 1, plan_id: 5))

          assert_equal [ 55 ], out.user_crop_ids
          assert_equal({ 99 => 55 }, out.reference_crop_id_to_user_crop_id)
        end

        test "raises RecordInvalid when crop limit exceeded" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_crop_reference_rows).returns([ reference_row_wire ])

          user_crop_gateway = mock("user_crop_gateway")
          user_crop_gateway.expects(:find_by_user_id_and_source_crop_id).returns(nil)
          user_crop_gateway.expects(:create).never

          crop_gateway = mock("crop_gateway")
          crop_gateway.expects(:count_user_owned_non_reference_crops).with(user_id: 1).returns(20)

          err = assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
            build_interactor(
              read_gateway: read_gateway,
              user_crop_gateway: user_crop_gateway,
              crop_gateway: crop_gateway
            ).call(Dtos::PlanSaveEnsureUserCropsInput.new(user_id: 1, plan_id: 5))
          end
          assert_equal "activerecord.errors.models.crop.attributes.user.crop_limit_exceeded", err.message
        end
      end
    end
  end
end
