# frozen_string_literal: true

module Presenters
  module Html
    module InteractionRule
      class InteractionRuleDetailHtmlPresenter < Domain::InteractionRule::Ports::InteractionRuleDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(interaction_rule_entity)
          @view.instance_variable_set(:@interaction_rule, interaction_rule_entity)
          # show アクションでは何もしない（テンプレート表示）
        end

        def on_failure(error_dto)
          error_message = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.render :error, status: :internal_server_error, locals: { error: error_message }
        end
      end
    end
  end
end