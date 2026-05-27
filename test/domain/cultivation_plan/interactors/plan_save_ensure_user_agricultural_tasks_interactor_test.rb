# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PlanSaveEnsureUserAgriculturalTasksInteractorTest < DomainLibTestCase
        def build_translator
          Object.new.tap do |o|
            o.define_singleton_method(:t) do |key, **opts|
              opts.empty? ? key.to_s : "#{key}|#{opts.sort.to_h.inspect}"
            end
          end
        end

        def template_link(reference_crop_id: 10, name: "作業A")
          Dtos::PublicPlanSaveCropTaskTemplateLinkRow.new(
            reference_crop_id: reference_crop_id,
            name: name,
            time_per_sqm: 1.5,
            is_reference: false
          )
        end

        def agricultural_task_row(task_id: 300, crop_ids: [ 10 ], name: "作業A")
          links = crop_ids.map { |crop_id| template_link(reference_crop_id: crop_id, name: name) }
          Dtos::PublicPlanSaveAgriculturalTaskReferenceRow.new(
            reference_agricultural_task_id: task_id,
            name: name,
            time_per_sqm: 1.5,
            region: "jp",
            linked_reference_crop_ids: crop_ids,
            template_links: links
          )
        end

        def build_interactor(read_gateway:, user_agricultural_task_gateway:, logger: nil, translator: nil)
          PlanSaveEnsureUserAgriculturalTasksInteractor.new(
            read_gateway: read_gateway,
            user_agricultural_task_gateway: user_agricultural_task_gateway,
            logger: logger || CapturingLogger.new,
            translator: translator || build_translator
          )
        end

        def default_input
          Dtos::PlanSaveEnsureUserAgriculturalTasksInput.new(
            user_id: 1,
            region: "jp",
            reference_crop_id_to_user_crop_id: { 10 => 101 }
          )
        end

        test "returns empty output without calling read when reference_crop_ids empty" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_agricultural_task_reference_rows).never

          user_gateway = mock("user_agricultural_task_gateway")
          user_gateway.expects(:find_by_user_id_and_source_agricultural_task_id).never

          out = build_interactor(
            read_gateway: read_gateway,
            user_agricultural_task_gateway: user_gateway
          ).call(
            Dtos::PlanSaveEnsureUserAgriculturalTasksInput.new(
              user_id: 1,
              region: "jp",
              reference_crop_id_to_user_crop_id: {}
            )
          )

          assert_empty out.user_agricultural_task_ids
          assert_empty out.skipped_agricultural_task_ids
          assert_empty out.reference_agricultural_task_id_to_user_task_id
        end

        test "creates user agricultural task and crop task template when intersecting plan crops" do
          row = agricultural_task_row
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_agricultural_task_reference_rows).with(region: "jp").returns([ row ])

          user_gateway = mock("user_agricultural_task_gateway")
          user_gateway.expects(:find_by_user_id_and_source_agricultural_task_id).with(
            user_id: 1,
            source_agricultural_task_id: 300
          ).returns(nil)
          user_gateway.expects(:create).with(
            user_id: 1,
            attributes: has_entries(
              name: "作業A",
              source_agricultural_task_id: 300,
              is_reference: false
            )
          ).returns(Dtos::PlanSaveUserAgriculturalTaskSnapshot.new(id: 88, name: "作業A"))
          user_gateway.expects(:find_crop_task_template).with(
            crop_id: 101,
            agricultural_task_id: 88
          ).returns(nil)
          user_gateway.expects(:create_crop_task_template).with(
            crop_id: 101,
            agricultural_task_id: 88,
            attributes: has_entries(name: "作業A", is_reference: false)
          ).returns(Dtos::PlanSaveCropTaskTemplateLinkSnapshot.new(id: 501))

          out = build_interactor(
            read_gateway: read_gateway,
            user_agricultural_task_gateway: user_gateway
          ).call(default_input)

          assert_equal [ 88 ], out.user_agricultural_task_ids
          assert_empty out.skipped_agricultural_task_ids
          assert_equal({ 300 => 88 }, out.reference_agricultural_task_id_to_user_task_id)
        end

        test "skips existing user agricultural task but still syncs crop task templates" do
          row = agricultural_task_row
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_agricultural_task_reference_rows).returns([ row ])

          user_gateway = mock("user_agricultural_task_gateway")
          user_gateway.expects(:find_by_user_id_and_source_agricultural_task_id).returns(
            Dtos::PlanSaveUserAgriculturalTaskSnapshot.new(id: 77, name: "既存作業")
          )
          user_gateway.expects(:create).never
          user_gateway.expects(:find_crop_task_template).with(
            crop_id: 101,
            agricultural_task_id: 77
          ).returns(nil)
          user_gateway.expects(:create_crop_task_template).with(
            crop_id: 101,
            agricultural_task_id: 77,
            attributes: has_entries(name: "既存作業")
          ).returns(Dtos::PlanSaveCropTaskTemplateLinkSnapshot.new(id: 502))

          out = build_interactor(
            read_gateway: read_gateway,
            user_agricultural_task_gateway: user_gateway
          ).call(default_input)

          assert_equal [ 77 ], out.user_agricultural_task_ids
          assert_equal [ 77 ], out.skipped_agricultural_task_ids
          assert_equal({ 300 => 77 }, out.reference_agricultural_task_id_to_user_task_id)
        end

        test "skips row that does not intersect plan crops" do
          row = agricultural_task_row(crop_ids: [ 99 ])
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_agricultural_task_reference_rows).returns([ row ])

          user_gateway = mock("user_agricultural_task_gateway")
          user_gateway.expects(:find_by_user_id_and_source_agricultural_task_id).never
          user_gateway.expects(:create).never

          out = build_interactor(
            read_gateway: read_gateway,
            user_agricultural_task_gateway: user_gateway
          ).call(default_input)

          assert_empty out.user_agricultural_task_ids
        end

        test "does not create crop task template when link already exists" do
          row = agricultural_task_row
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_agricultural_task_reference_rows).returns([ row ])

          user_gateway = mock("user_agricultural_task_gateway")
          user_gateway.expects(:find_by_user_id_and_source_agricultural_task_id).returns(nil)
          user_gateway.expects(:create).returns(
            Dtos::PlanSaveUserAgriculturalTaskSnapshot.new(id: 88, name: "作業A")
          )
          user_gateway.expects(:find_crop_task_template).returns(
            Dtos::PlanSaveCropTaskTemplateLinkSnapshot.new(id: 501)
          )
          user_gateway.expects(:create_crop_task_template).never

          build_interactor(
            read_gateway: read_gateway,
            user_agricultural_task_gateway: user_gateway
          ).call(default_input)
        end
      end
    end
  end
end
