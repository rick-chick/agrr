# frozen_string_literal: true

module Presenters
  module Api
    module InteractionRule
      class InteractionRuleListPresenter < Domain::InteractionRule::Ports::InteractionRuleListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(rules)
          array = rules_to_array(rules)
          json = array.map { |e| entity_to_json(e) }
          @view.render_response(json: json, status: :ok)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.render_response(json: { error: msg }, status: :unprocessable_entity)
        end

        private

        def rules_to_array(rules)
          return rules if rules.is_a?(Array)
          return [] unless rules.respond_to?(:[]) && rules[:interaction_rules]
          Array(rules[:interaction_rules])
        end

        def entity_to_json(entity)
          {
            id: entity.id,
            user_id: entity.user_id,
            rule_type: entity.rule_type,
            source_group: entity.source_group,
            target_group: entity.target_group,
            impact_ratio: entity.impact_ratio.respond_to?(:to_f) ? entity.impact_ratio.to_f : entity.impact_ratio,
            is_directional: entity.is_directional,
            description: entity.description,
            region: entity.region,
            is_reference: entity.is_reference,
            created_at: entity.created_at,
            updated_at: entity.updated_at
          }
        end
      end
    end
  end
end
