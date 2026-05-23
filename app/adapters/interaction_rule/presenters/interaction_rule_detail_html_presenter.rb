# frozen_string_literal: true

module Adapters
  module InteractionRule
    module Presenters
      class InteractionRuleDetailHtmlPresenter < Domain::InteractionRule::Ports::InteractionRuleDetailOutputPort
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:)
          @view = view
        end

        def on_success(rule_detail_dto)
          @view.instance_variable_set(:@interaction_rule, rule_detail_dto.rule)
          assign_html_display(@view, rule_detail_dto.html_display) if rule_detail_dto.html_display
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
