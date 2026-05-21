# frozen_string_literal: true

module Domain
  module InteractionRule
    module Interactors
      class InteractionRuleDestroyInteractor < Domain::InteractionRule::Ports::InteractionRuleDestroyInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(rule_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::InteractionRulePolicy.record_access_filter(user)
          result = @gateway.soft_delete_with_undo(
            user: user,
            rule_id: rule_id,
            auto_hide_after: 5000,
            translator: @translator,
            access_filter: access_filter
          )
          if result[:success]
            destroy_output_dto = Domain::InteractionRule::Dtos::InteractionRuleDestroyOutput.new(undo: result[:undo_entity])
            @output_port.on_success(destroy_output_dto)
          else
            @output_port.on_failure(result[:error_dto])
          end
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(@translator.t("interaction_rules.flash.not_found")))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
