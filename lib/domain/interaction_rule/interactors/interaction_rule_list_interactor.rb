# frozen_string_literal: true

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleListInteractor < Domain::InteractionRule::Ports::InteractionRuleListInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call
          user = User.find(@user_id)
          visible_scope = Domain::Shared::Policies::InteractionRulePolicy.visible_scope(::InteractionRule, user)
          rules = @gateway.list(visible_scope)
          reference_rules = rules.select(&:is_reference)
          interaction_rules = rules.reject(&:is_reference)
          @output_port.on_success(interaction_rules: interaction_rules, reference_rules: reference_rules)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
