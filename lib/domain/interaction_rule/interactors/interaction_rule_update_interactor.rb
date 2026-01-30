# frozen_string_literal: true

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleUpdateInteractor < Domain::InteractionRule::Ports::InteractionRuleUpdateInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(update_input_dto)
          user = User.find(@user_id)
          puts "DEBUG: User admin? = #{user.admin?}, user_id = #{user.id}"
          attrs = {}
          attrs[:rule_type] = update_input_dto.rule_type unless update_input_dto.rule_type.nil?
          attrs[:source_group] = update_input_dto.source_group unless update_input_dto.source_group.nil?
          attrs[:target_group] = update_input_dto.target_group unless update_input_dto.target_group.nil?
          attrs[:impact_ratio] = update_input_dto.impact_ratio if !update_input_dto.impact_ratio.nil?
          attrs[:is_directional] = update_input_dto.is_directional if !update_input_dto.is_directional.nil?
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?

          rule_model = Domain::Shared::Policies::InteractionRulePolicy.find_editable!(::InteractionRule, user, update_input_dto.id)
          Domain::Shared::Policies::InteractionRulePolicy.apply_update!(user, rule_model, attrs)
          raise StandardError, rule_model.errors.full_messages.join(', ') if rule_model.errors.any?

          reloaded_rule = rule_model.reload
          puts "DEBUG: Reloaded rule - id: #{reloaded_rule.id}, region: #{reloaded_rule.region}"
          rule_entity = Domain::InteractionRule::Entities::InteractionRuleEntity.from_model(reloaded_rule)
          @output_port.on_success(rule_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
