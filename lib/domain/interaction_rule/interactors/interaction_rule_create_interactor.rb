# frozen_string_literal: true

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleCreateInteractor < Domain::InteractionRule::Ports::InteractionRuleCreateInputPort
        def initialize(output_port:, user_id:, gateway:, logger:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(create_input_dto)
          user = @user_lookup.find(@user_id)
          rule_entity = @gateway.create_for_user(user, {
            rule_type: create_input_dto.rule_type,
            source_group: create_input_dto.source_group,
            target_group: create_input_dto.target_group,
            impact_ratio: create_input_dto.impact_ratio,
            is_directional: create_input_dto.is_directional,
            description: create_input_dto.description,
            region: create_input_dto.region,
            is_reference: create_input_dto.is_reference
          })

          @output_port.on_success(rule_entity)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
