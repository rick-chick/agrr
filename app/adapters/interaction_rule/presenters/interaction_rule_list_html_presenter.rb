# frozen_string_literal: true

module Adapters
  module InteractionRule
    module Presenters
      class InteractionRuleListHtmlPresenter < Domain::InteractionRule::Ports::InteractionRuleListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(result)
          @view.instance_variable_set(:@interaction_rules, result[:interaction_rules] || [])
          @view.instance_variable_set(:@reference_rules, result[:reference_rules] || [])
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_back fallback_location: @view.interaction_rules_path,
                               alert: I18n.t("interaction_rules.flash.no_permission")
            return
          end

          @view.flash.now[:alert] = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.instance_variable_set(:@interaction_rules, [])
          @view.instance_variable_set(:@reference_rules, [])
        end
      end
    end
  end
end
