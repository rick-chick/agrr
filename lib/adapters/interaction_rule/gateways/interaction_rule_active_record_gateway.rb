# frozen_string_literal: true

module Adapters
  module InteractionRule
    module Gateways
      class InteractionRuleActiveRecordGateway < Domain::InteractionRule::Gateways::InteractionRuleGateway
        def list(scope = nil)
          query = scope || ::InteractionRule.all
          query.map { |record| Domain::InteractionRule::Entities::InteractionRuleEntity.from_model(record) }
        end

        def find_by_id(rule_id)
          rule = ::InteractionRule.find(rule_id)
          Domain::InteractionRule::Entities::InteractionRuleEntity.from_model(rule)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'InteractionRule not found'
        end

        def create(create_input_dto)
          rule = ::InteractionRule.new(
            rule_type: create_input_dto.rule_type,
            source_group: create_input_dto.source_group,
            target_group: create_input_dto.target_group,
            impact_ratio: create_input_dto.impact_ratio,
            is_directional: create_input_dto.is_directional,
            description: create_input_dto.description,
            region: create_input_dto.region
          )
          raise StandardError, rule.errors.full_messages.join(', ') unless rule.save

          Domain::InteractionRule::Entities::InteractionRuleEntity.from_model(rule)
        end

        def update(rule_id, update_input_dto)
          rule = ::InteractionRule.find(rule_id)
          attrs = {}
          attrs[:rule_type] = update_input_dto.rule_type if update_input_dto.rule_type.present?
          attrs[:source_group] = update_input_dto.source_group if update_input_dto.source_group.present?
          attrs[:target_group] = update_input_dto.target_group if update_input_dto.target_group.present?
          attrs[:impact_ratio] = update_input_dto.impact_ratio if !update_input_dto.impact_ratio.nil?
          attrs[:is_directional] = update_input_dto.is_directional if !update_input_dto.is_directional.nil?
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?

          rule.update(attrs)
          raise StandardError, rule.errors.full_messages.join(', ') if rule.errors.any?

          Domain::InteractionRule::Entities::InteractionRuleEntity.from_model(rule.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'InteractionRule not found'
        end

        def destroy(rule_id)
          rule = ::InteractionRule.find(rule_id)
          rule.destroy!
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'InteractionRule not found'
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise StandardError, I18n.t('interaction_rules.flash.cannot_delete_in_use')
        end
      end
    end
  end
end
