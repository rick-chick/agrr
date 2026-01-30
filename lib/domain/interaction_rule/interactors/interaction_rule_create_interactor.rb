# frozen_string_literal: true

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleCreateInteractor < Domain::InteractionRule::Ports::InteractionRuleCreateInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(create_input_dto)
          user = User.find(@user_id)
          rule_model, = Domain::Shared::Policies::InteractionRulePolicy.build_for_create(::InteractionRule, user, {
            rule_type: create_input_dto.rule_type,
            source_group: create_input_dto.source_group,
            target_group: create_input_dto.target_group,
            impact_ratio: create_input_dto.impact_ratio,
            is_directional: create_input_dto.is_directional,
            description: create_input_dto.description,
            region: create_input_dto.region,
            is_reference: create_input_dto.is_reference
          })
          rule_model.save!

          rule_entity = Domain::InteractionRule::Entities::InteractionRuleEntity.from_model(rule_model)
          @output_port.on_success(rule_entity)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
