# frozen_string_literal: true

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleUpdateInteractor < Domain::InteractionRule::Ports::InteractionRuleUpdateInputPort
        def initialize(output_port:, user_id:, gateway:, logger:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(update_input_dto)
          user = @user_lookup.find(@user_id)

          unless update_input_dto.is_reference.nil?
            requested = Domain::Shared::TypeConverters::BooleanConverter.cast(update_input_dto.is_reference)
            requested = false if requested.nil?
            current_entity = @gateway.find_authorized_for_edit(user, update_input_dto.id)
            if requested != current_entity.reference? && !user.admin?
              raise Domain::Shared::Exceptions::RecordInvalid.new(@translator.t("interaction_rules.flash.reference_flag_admin_only"))
            end
          end

          attrs = {}
          attrs[:rule_type] = update_input_dto.rule_type unless update_input_dto.rule_type.nil?
          attrs[:source_group] = update_input_dto.source_group unless update_input_dto.source_group.nil?
          attrs[:target_group] = update_input_dto.target_group unless update_input_dto.target_group.nil?
          attrs[:impact_ratio] = update_input_dto.impact_ratio if !update_input_dto.impact_ratio.nil?
          attrs[:is_directional] = update_input_dto.is_directional if !update_input_dto.is_directional.nil?
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?
          attrs[:is_reference] = update_input_dto.is_reference if !update_input_dto.is_reference.nil?

          rule_entity = @gateway.update_for_user(user, update_input_dto.id, attrs)

          @output_port.on_success(rule_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
