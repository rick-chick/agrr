# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class PlanSaveInteractionRuleAttributesMapperTest < DomainLibTestCase
        def build_row(impact_ratio: 0.7, is_directional: false)
          Dtos::PublicPlanSaveInteractionRuleReferenceRow.new(
            reference_interaction_rule_id: 42,
            rule_type: "continuous_cultivation",
            source_group: "GroupSrc",
            target_group: "GroupTgt",
            impact_ratio: impact_ratio,
            is_directional: is_directional,
            region: "jp",
            description: "連作説明"
          )
        end

        test "attributes_for_create maps reference row to user rule attributes" do
          row = build_row(impact_ratio: 0.7, is_directional: false)

          attrs = PlanSaveInteractionRuleAttributesMapper.attributes_for_create(row: row)

          assert_equal "continuous_cultivation", attrs[:rule_type]
          assert_equal "GroupSrc", attrs[:source_group]
          assert_equal "GroupTgt", attrs[:target_group]
          assert_in_delta 0.7, attrs[:impact_ratio], 0.0001
          assert_equal false, attrs[:is_directional]
          assert_equal "jp", attrs[:region]
          assert_equal "連作説明", attrs[:description]
          assert_equal false, attrs[:is_reference]
          assert_equal 42, attrs[:source_interaction_rule_id]
        end
      end
    end
  end
end
