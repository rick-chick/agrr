# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class CultivationPlanOptimizeInteractorInteractionRulesTest < DomainLibTestCase
        test "prepare_interaction_rules returns nil when gateway list is empty" do
          rule_gateway = mock
          rule_gateway.expects(:list_by_cultivation_plan_id).with(cultivation_plan_id: 9).returns([])

          builder = mock
          builder.expects(:build_array_from).never

          optimizer = CultivationPlanOptimizeInteractor.new(
            plan_id: 9,
            channel_class: "OptimizationChannel",
            allocation_gateway: nil,
            interaction_rule_gateway: rule_gateway,
            interaction_rule_agrr_format_builder: builder,
            cultivation_plan_gateway: nil,
            private_read_gateway: nil,
            advance_phase_interactor: nil,
            logger: CapturingLogger.new,
            weather_prediction_interactor_factory: ->(**) {},
            clock: Struct.new(:today).new(Date.new(2026, 1, 1))
          )

          assert_nil optimizer.send(:prepare_interaction_rules)
        end

        test "prepare_interaction_rules builds agrr array via port when rules exist" do
          entity = Domain::InteractionRule::Entities::InteractionRuleEntity.new(
            id: 1,
            user_id: nil,
            rule_type: "continuous_cultivation",
            source_group: "A",
            target_group: "B",
            impact_ratio: 0.5,
            is_directional: true,
            description: nil,
            region: "jp",
            is_reference: true,
            created_at: nil,
            updated_at: nil
          )
          rule_gateway = mock
          rule_gateway.expects(:list_by_cultivation_plan_id).with(cultivation_plan_id: 9).returns([ entity ])

          builder = mock
          builder.expects(:build_array_from).with([ entity ]).returns([ { "rule_id" => "rule_1" } ])

          optimizer = CultivationPlanOptimizeInteractor.new(
            plan_id: 9,
            channel_class: "OptimizationChannel",
            allocation_gateway: nil,
            interaction_rule_gateway: rule_gateway,
            interaction_rule_agrr_format_builder: builder,
            cultivation_plan_gateway: nil,
            private_read_gateway: nil,
            advance_phase_interactor: nil,
            logger: CapturingLogger.new,
            weather_prediction_interactor_factory: ->(**) {},
            clock: Struct.new(:today).new(Date.new(2026, 1, 1))
          )

          rules = optimizer.send(:prepare_interaction_rules)

          assert_equal 1, rules.size
          assert_equal "rule_1", rules.first["rule_id"]
        end
      end
    end
  end
end
