# frozen_string_literal: true

module Presenters
  module Html
    module InteractionRule
      class InteractionRuleListHtmlPresenter < Domain::InteractionRule::Ports::InteractionRuleListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(result)
          # view は ActiveRecord モデルを期待するため ID から取得
          @view.instance_variable_set(:@interaction_rules, (result[:interaction_rules] || []).map { |e| ::InteractionRule.find(e.id) })
          @view.instance_variable_set(:@reference_rules, (result[:reference_rules] || []).map { |e| ::InteractionRule.find(e.id) })
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.instance_variable_set(:@interaction_rules, [])
          @view.instance_variable_set(:@reference_rules, [])
        end
      end
    end
  end
end