# frozen_string_literal: true

module Adapters
  module InteractionRule
    module Presenters
      module Html
        class InteractionRuleDestroyHtmlPresenter < Domain::InteractionRule::Ports::InteractionRuleDestroyOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(destroy_output_dto)
            # 成功時は undo 情報を用いてリダイレクト
            undo_event = destroy_output_dto.undo
            @view.redirect_back(
              fallback_location: @view.interaction_rules_path,
              notice: I18n.t("deletion_undo.redirect_notice", resource: undo_event.metadata["resource_label"])
            )
          end

          def on_failure(error_dto)
            alert =
              if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
                I18n.t("interaction_rules.flash.not_found")
              else
                msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
                if msg == "InteractionRule not found"
                  I18n.t("interaction_rules.flash.not_found")
                else
                  msg
                end
              end
            @view.redirect_back(
              fallback_location: @view.interaction_rules_path,
              alert: alert
            )
          end
        end
      end
    end
  end
end
