# frozen_string_literal: true

module Adapters
  module InteractionRule
    module Presenters
      class InteractionRuleCreateHtmlPresenter < Domain::InteractionRule::Ports::InteractionRuleCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(rule)
          # 成功時は作成したルールの詳細ページにリダイレクト
          @view.redirect_to @view.interaction_rule_path(rule.id), notice: I18n.t("interaction_rules.flash.created")
        end

        def on_failure(error_dto)
          error_message = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          if error_message == I18n.t("interaction_rules.flash.reference_only_admin")
            @view.redirect_to @view.interaction_rules_path, alert: error_message
            return
          end

          @view.redirect_to @view.interaction_rules_path, alert: error_message
        end
      end
    end
  end
end
