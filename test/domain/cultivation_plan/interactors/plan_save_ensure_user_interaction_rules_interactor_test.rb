# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PlanSaveEnsureUserInteractionRulesInteractorTest < DomainLibTestCase
        def build_translator
          Object.new.tap do |o|
            o.define_singleton_method(:t) do |key, **opts|
              opts.empty? ? key.to_s : "#{key}|#{opts.sort.to_h.inspect}"
            end
          end
        end

        def interaction_rule_wire(
          reference_id: 100,
          source_group: "GroupA",
          target_group: "GroupB",
          region: "jp",
          rule_type: "continuous_cultivation"
        )
          Dtos::PublicPlanSaveInteractionRuleReferenceRow.new(
            reference_interaction_rule_id: reference_id,
            rule_type: rule_type,
            source_group: source_group,
            target_group: target_group,
            impact_ratio: 0.5,
            is_directional: true,
            region: region,
            description: "desc"
          )
        end

        def build_interactor(read_gateway:, user_interaction_rule_gateway:, logger: nil, translator: nil)
          PlanSaveEnsureUserInteractionRulesInteractor.new(
            read_gateway: read_gateway,
            user_interaction_rule_gateway: user_interaction_rule_gateway,
            logger: logger || CapturingLogger.new,
            translator: translator || build_translator
          )
        end

        def default_input(crop_groups: %w[GroupA GroupB])
          Dtos::PlanSaveEnsureUserInteractionRulesInput.new(
            user_id: 1,
            region: "jp",
            reference_crop_groups: crop_groups
          )
        end

        test "returns empty output when reference_crop_groups is empty without calling read gateway" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_interaction_rule_reference_rows).never

          user_gateway = mock("user_interaction_rule_gateway")

          out = build_interactor(
            read_gateway: read_gateway,
            user_interaction_rule_gateway: user_gateway
          ).call(
            Dtos::PlanSaveEnsureUserInteractionRulesInput.new(
              user_id: 1,
              region: "jp",
              reference_crop_groups: []
            )
          )

          assert_empty out.user_interaction_rule_ids
          assert_empty out.skipped_interaction_rule_ids
        end

        test "skips non-continuous_cultivation rule types from read gateway" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_interaction_rule_reference_rows).returns(
            [
              interaction_rule_wire(rule_type: "other_type"),
              interaction_rule_wire(rule_type: "continuous_cultivation", source_group: "GroupA", target_group: "GroupB")
            ]
          )

          user_gateway = mock("user_interaction_rule_gateway")
          user_gateway.expects(:find_by_user_id_and_source_interaction_rule_id).once.returns(nil)
          user_gateway.expects(:find_by_user_id_and_rule_type_and_source_group_and_target_group_and_region).once.returns(nil)
          user_gateway.expects(:create).once.returns(
            Dtos::PlanSaveUserInteractionRuleSnapshot.new(id: 50)
          )

          out = build_interactor(
            read_gateway: read_gateway,
            user_interaction_rule_gateway: user_gateway
          ).call(default_input)

          assert_equal [ 50 ], out.user_interaction_rule_ids
        end

        test "skips rows that do not intersect reference_crop_groups" do
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_interaction_rule_reference_rows).with(region: "jp").returns(
            [ interaction_rule_wire(source_group: "Other", target_group: "Elsewhere") ]
          )

          user_gateway = mock("user_interaction_rule_gateway")
          user_gateway.expects(:find_by_user_id_and_source_interaction_rule_id).never
          user_gateway.expects(:create).never

          out = build_interactor(
            read_gateway: read_gateway,
            user_interaction_rule_gateway: user_gateway
          ).call(default_input(crop_groups: %w[GroupA]))

          assert_empty out.user_interaction_rule_ids
          assert_empty out.skipped_interaction_rule_ids
        end

        test "creates user interaction rules for each matching reference row" do
          row_a = interaction_rule_wire(reference_id: 100, source_group: "GroupA", target_group: "GroupB")
          row_b = interaction_rule_wire(reference_id: 101, source_group: "GroupC", target_group: "GroupD")
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_interaction_rule_reference_rows).returns([ row_a, row_b ])

          user_gateway = mock("user_interaction_rule_gateway")
          user_gateway.expects(:find_by_user_id_and_source_interaction_rule_id).twice.returns(nil)
          user_gateway.expects(:find_by_user_id_and_rule_type_and_source_group_and_target_group_and_region).twice.returns(nil)
          user_gateway.expects(:create).twice.returns(
            Dtos::PlanSaveUserInteractionRuleSnapshot.new(id: 55),
            Dtos::PlanSaveUserInteractionRuleSnapshot.new(id: 56)
          )

          out = build_interactor(
            read_gateway: read_gateway,
            user_interaction_rule_gateway: user_gateway
          ).call(
            Dtos::PlanSaveEnsureUserInteractionRulesInput.new(
              user_id: 1,
              region: "jp",
              reference_crop_groups: %w[GroupA GroupB GroupC GroupD]
            )
          )

          assert_equal [ 55, 56 ], out.user_interaction_rule_ids
          assert_empty out.skipped_interaction_rule_ids
        end

        test "creates user interaction rule when no existing match" do
          row = interaction_rule_wire
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_interaction_rule_reference_rows).returns([ row ])

          user_gateway = mock("user_interaction_rule_gateway")
          user_gateway.expects(:find_by_user_id_and_source_interaction_rule_id).with(
            user_id: 1,
            source_interaction_rule_id: 100
          ).returns(nil)
          user_gateway.expects(:find_by_user_id_and_rule_type_and_source_group_and_target_group_and_region).with(
            user_id: 1,
            rule_type: "continuous_cultivation",
            source_group: "GroupA",
            target_group: "GroupB",
            region: "jp"
          ).returns(nil)
          user_gateway.expects(:create).with(
            user_id: 1,
            attributes: has_entries(
              rule_type: "continuous_cultivation",
              source_group: "GroupA",
              target_group: "GroupB",
              source_interaction_rule_id: 100,
              is_reference: false
            )
          ).returns(Dtos::PlanSaveUserInteractionRuleSnapshot.new(id: 55))

          out = build_interactor(
            read_gateway: read_gateway,
            user_interaction_rule_gateway: user_gateway
          ).call(default_input)

          assert_equal [ 55 ], out.user_interaction_rule_ids
          assert_empty out.skipped_interaction_rule_ids
        end

        test "reuses existing rule by source id and records skip" do
          row = interaction_rule_wire
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_interaction_rule_reference_rows).returns([ row ])

          user_gateway = mock("user_interaction_rule_gateway")
          user_gateway.expects(:find_by_user_id_and_source_interaction_rule_id).returns(
            Dtos::PlanSaveUserInteractionRuleSnapshot.new(id: 77, source_interaction_rule_id: 100)
          )
          user_gateway.expects(:find_by_user_id_and_rule_type_and_source_group_and_target_group_and_region).never
          user_gateway.expects(:update).never
          user_gateway.expects(:create).never

          out = build_interactor(
            read_gateway: read_gateway,
            user_interaction_rule_gateway: user_gateway
          ).call(default_input)

          assert_equal [ 77 ], out.user_interaction_rule_ids
          assert_equal [ 77 ], out.skipped_interaction_rule_ids
        end

        test "updates source link when matched by natural key without source id" do
          row = interaction_rule_wire
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_interaction_rule_reference_rows).returns([ row ])

          user_gateway = mock("user_interaction_rule_gateway")
          user_gateway.expects(:find_by_user_id_and_source_interaction_rule_id).returns(nil)
          user_gateway.expects(:find_by_user_id_and_rule_type_and_source_group_and_target_group_and_region).returns(
            Dtos::PlanSaveUserInteractionRuleSnapshot.new(id: 88, source_interaction_rule_id: nil)
          )
          user_gateway.expects(:update).with(
            user_id: 1,
            interaction_rule_id: 88,
            attributes: { source_interaction_rule_id: 100 }
          ).returns(
            Dtos::PlanSaveUserInteractionRuleSnapshot.new(id: 88, source_interaction_rule_id: 100)
          )
          user_gateway.expects(:create).never

          out = build_interactor(
            read_gateway: read_gateway,
            user_interaction_rule_gateway: user_gateway
          ).call(default_input)

          assert_equal [ 88 ], out.user_interaction_rule_ids
          assert_equal [ 88 ], out.skipped_interaction_rule_ids
        end

        test "does not update when natural key match already has source id" do
          row = interaction_rule_wire
          read_gateway = mock("read_gateway")
          read_gateway.expects(:list_interaction_rule_reference_rows).returns([ row ])

          user_gateway = mock("user_interaction_rule_gateway")
          user_gateway.expects(:find_by_user_id_and_source_interaction_rule_id).returns(nil)
          user_gateway.expects(:find_by_user_id_and_rule_type_and_source_group_and_target_group_and_region).returns(
            Dtos::PlanSaveUserInteractionRuleSnapshot.new(id: 99, source_interaction_rule_id: 50)
          )
          user_gateway.expects(:update).never
          user_gateway.expects(:create).never

          out = build_interactor(
            read_gateway: read_gateway,
            user_interaction_rule_gateway: user_gateway
          ).call(default_input)

          assert_equal [ 99 ], out.user_interaction_rule_ids
          assert_equal [ 99 ], out.skipped_interaction_rule_ids
        end
      end
    end
  end
end
