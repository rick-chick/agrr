# frozen_string_literal: true

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleDestroyInteractor < Domain::InteractionRule::Ports::InteractionRuleDestroyInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(rule_id)
          user = User.find(@user_id)
          rule_model = Domain::Shared::Policies::InteractionRulePolicy.find_editable!(::InteractionRule, user, rule_id)
          undo_response = DeletionUndo::Manager.schedule(
            record: rule_model,
            actor: user,
            toast_message: I18n.t('interaction_rules.undo.toast', source: rule_model.source_group, target: rule_model.target_group)
          )
          destroy_output_dto = Domain::InteractionRule::Dtos::InteractionRuleDestroyOutputDto.new(undo: undo_response)
          @output_port.on_success(destroy_output_dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
