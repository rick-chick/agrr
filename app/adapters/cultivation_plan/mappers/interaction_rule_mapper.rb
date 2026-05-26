# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      # 公開プラン保存セッション用 InteractionRule マッパー（AR を扱うため Adapter 層）。
      class InteractionRuleMapper
        def initialize(ctx)
          @ctx = ctx
        end

        def copy_interaction_rules_for_region(region)
          reference_crop_groups = @ctx.get_reference_crop_groups
          return [] if reference_crop_groups.empty?

          reference_scope = ::InteractionRule.reference.where(rule_type: "continuous_cultivation")
          reference_scope = reference_scope.where(region: [ region, nil ]) if region.present?

          interaction_rules = []

          reference_scope.find_each do |reference_rule|
            next unless reference_crop_groups.include?(reference_rule.source_group) ||
                        reference_crop_groups.include?(reference_rule.target_group)

            existing_rule = @ctx.user.interaction_rules.find_by(source_interaction_rule_id: reference_rule.id)

            unless existing_rule
              existing_rule = @ctx.user.interaction_rules.find_by(
                rule_type: reference_rule.rule_type,
                source_group: reference_rule.source_group,
                target_group: reference_rule.target_group,
                region: reference_rule.region,
                is_reference: false
              )
            end

            if existing_rule
              if existing_rule.source_interaction_rule_id.nil?
                existing_rule.update!(source_interaction_rule_id: reference_rule.id)
              end
              @ctx.result.add_skip(:interaction_rules, existing_rule.id)
              interaction_rules << existing_rule
              next
            end

            new_rule = @ctx.user.interaction_rules.create!(
              rule_type: reference_rule.rule_type,
              source_group: reference_rule.source_group,
              target_group: reference_rule.target_group,
              impact_ratio: reference_rule.impact_ratio.to_f,
              is_directional: !!reference_rule.is_directional,
              region: reference_rule.region,
              description: reference_rule.description,
              source_interaction_rule_id: reference_rule.id
            )

            interaction_rules << new_rule
          end

          interaction_rules
        end
      end
    end
  end
end
