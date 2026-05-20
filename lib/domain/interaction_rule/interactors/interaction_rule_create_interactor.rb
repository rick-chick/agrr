# frozen_string_literal: true

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleCreateInteractor < Domain::InteractionRule::Ports::InteractionRuleCreateInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(create_input_dto)
          user = @user_lookup.find(@user_id)
          is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(create_input_dto.is_reference) || false
          if is_reference && !user.admin?
            raise Domain::Shared::Exceptions::RecordInvalid.new(@translator.t("interaction_rules.flash.reference_only_admin"))
          end

          attrs = Domain::Shared::Policies::InteractionRulePolicy.normalize_attrs_for_create(user, {
            rule_type: create_input_dto.rule_type,
            source_group: create_input_dto.source_group,
            target_group: create_input_dto.target_group,
            impact_ratio: create_input_dto.impact_ratio,
            is_directional: create_input_dto.is_directional,
            description: create_input_dto.description,
            region: create_input_dto.region,
            is_reference: is_reference
          })
          rule_entity = @gateway.create_for_user(user, attrs)

          @output_port.on_success(rule_entity)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
