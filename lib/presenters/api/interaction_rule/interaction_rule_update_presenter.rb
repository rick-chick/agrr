# frozen_string_literal: true

module Presenters
  module Api
    module InteractionRule
      class InteractionRuleUpdatePresenter < Domain::InteractionRule::Ports::InteractionRuleUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(rule)
          json = entity_to_json(rule)
          @view.render_response(json: json, status: :ok)
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            msg = I18n.t('interaction_rules.flash.no_permission')
            status = :forbidden
          else
            msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
            status = if msg == 'InteractionRule not found'
                       :not_found
                     else
                       :unprocessable_entity
                     end
          end
          @view.render_response(json: { error: msg }, status: status)
        end

        private

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
