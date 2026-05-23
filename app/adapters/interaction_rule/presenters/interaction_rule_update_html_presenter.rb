# frozen_string_literal: true

module Adapters
  module InteractionRule
    module Presenters
      class InteractionRuleUpdateHtmlPresenter < Domain::InteractionRule::Ports::InteractionRuleUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(rule)
          # 成功時は詳細ページにリダイレクト
          @view.redirect_to @view.interaction_rule_path(rule.id), notice: I18n.t("interaction_rules.flash.updated")
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.flash[:alert] = I18n.t("interaction_rules.flash.no_permission")
            @view.redirect_to @view.interaction_rules_path
            return
          end

          if error_dto.is_a?(Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure)
            @view.redirect_to @view.interaction_rule_path(error_dto.resource_id), alert: error_dto.message
            return
          end

          error_message = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s

          @view.flash.now[:alert] = error_message
          @view.render :edit, status: :unprocessable_entity
        end
      end
    end
  end
end
