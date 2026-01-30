# frozen_string_literal: true

module Presenters
  module Html
    module InteractionRule
      class InteractionRuleCreateHtmlPresenter < Domain::InteractionRule::Ports::InteractionRuleCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(rule)
          # 成功時は作成したルールの詳細ページにリダイレクト
          @view.redirect_to @view.interaction_rule_path(rule.id), notice: I18n.t('interaction_rules.flash.created')
        end

        def on_failure(error_dto)
          # 失敗時は新規作成フォームを再表示
          error_message = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.render :new, status: :unprocessable_entity
        end
      end
    end
  end
end