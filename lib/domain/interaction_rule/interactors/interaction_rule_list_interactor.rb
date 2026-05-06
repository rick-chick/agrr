# frozen_string_literal: true

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleListInteractor < Domain::InteractionRule::Ports::InteractionRuleListInputPort
        def initialize(output_port:, user_id:, gateway:, logger:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          rules = @gateway.list_index_for_user(user)
          reference_rules = rules.select(&:is_reference)
          interaction_rules = rules.reject(&:is_reference)
          @output_port.on_success(interaction_rules: interaction_rules, reference_rules: reference_rules)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
