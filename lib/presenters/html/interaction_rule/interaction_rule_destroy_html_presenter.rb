# frozen_string_literal: true

module Presenters
  module Html
    module InteractionRule
      class InteractionRuleDestroyHtmlPresenter < Domain::InteractionRule::Ports::InteractionRuleDestroyOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(destroy_output_dto)
          # 成功時は undo 情報を用いてリダイレクト
          undo_event = destroy_output_dto.undo
          @view.redirect_back(
            fallback_location: @view.interaction_rules_path,
            notice: I18n.t('deletion_undo.redirect_notice', resource: undo_event.metadata['resource_label'])
          )
        end

        def on_failure(error_dto)
          # 失敗時はエラーメッセージを表示して一覧ページにリダイレクト
          error_message = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.redirect_back(
            fallback_location: @view.interaction_rules_path,
            alert: error_message
          )
        end
      end
    end
  end
end