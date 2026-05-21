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

          error_message = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          if error_message == I18n.t("interaction_rules.flash.reference_flag_admin_only")
            @view.redirect_to @view.interaction_rule_path(@view.params[:id]), alert: error_message
            return
          end

          @view.flash.now[:alert] = error_message
          @view.render :edit, status: :unprocessable_entity
        end
      end
    end
  end
end
