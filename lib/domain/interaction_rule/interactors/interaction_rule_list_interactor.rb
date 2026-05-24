# frozen_string_literal: true

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleListInteractor < Domain::InteractionRule::Ports::InteractionRuleListInputPort
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          filter = Domain::Shared::Policies::InteractionRulePolicy.index_list_filter(user)
          rules = @gateway.list_index_for_filter(filter)
          @output_port.on_success(rules)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
