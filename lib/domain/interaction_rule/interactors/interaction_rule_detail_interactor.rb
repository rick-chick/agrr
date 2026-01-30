# frozen_string_literal: true

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleDetailInteractor < Domain::InteractionRule::Ports::InteractionRuleDetailInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(rule_id)
          user = User.find(@user_id)
          rule_model = Domain::Shared::Policies::InteractionRulePolicy.find_visible!(::InteractionRule, user, rule_id)
          rule_entity = Domain::InteractionRule::Entities::InteractionRuleEntity.from_model(rule_model)
          rule_detail_dto = Domain::InteractionRule::Dtos::InteractionRuleDetailOutputDto.new(rule: rule_entity)
          @output_port.on_success(rule_detail_dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
