# frozen_string_literal: true

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleDetailInteractor < Domain::InteractionRule::Ports::InteractionRuleDetailInputPort
        def initialize(output_port:, user_id:, gateway:, logger:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(rule_id)
          user = @user_lookup.find(@user_id)
          rule_entity = @gateway.find_authorized_for_view(user, rule_id)
          rule_detail_dto = Domain::InteractionRule::Dtos::InteractionRuleDetailOutputDto.new(rule: rule_entity)
          @output_port.on_success(rule_detail_dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
