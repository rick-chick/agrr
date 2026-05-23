# frozen_string_literal: true

module Adapters
  module InteractionRule
    module Presenters
      class InteractionRuleLoadHtmlPresenter
        def initialize(view:, for_edit:)
          @view = view
          @for_edit = for_edit
        end

        def on_success(rule_entity)
          @view.instance_variable_set(:@interaction_rule, rule_entity)
          if @for_edit
            @view.instance_variable_set(
              :@form,
              Adapters::InteractionRule::Presenters::Forms::InteractionRuleForm.from_entity(rule_entity)
            )
          end
        end

        def on_failure(reason)
          alert =
            reason == :no_permission ? I18n.t("interaction_rules.flash.no_permission") : I18n.t("interaction_rules.flash.not_found")
          @view.redirect_to @view.interaction_rules_path, alert: alert
        end
      end
    end
  end
end
