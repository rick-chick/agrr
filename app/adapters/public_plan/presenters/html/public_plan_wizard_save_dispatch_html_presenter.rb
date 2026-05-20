# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      module Html
        # 公開プラン HTML `save_plan` の分岐結果をリダイレクト・セッションへ写す（保存成功・失敗は親クラス）。
        class PublicPlanWizardSaveDispatchHtmlPresenter < PublicPlanSaveFromSessionHtmlPresenter
          def on_plan_not_found
            @view.redirect_to @view.public_plans_path, alert: I18n.t("public_plans.errors.not_found")
          end

          def on_save_payload_unavailable(plan_id:)
            # ログは Interactor 側。HTTP 応答は送らない（従来の save_plan 枝と同様）。
            nil
          end

          def on_requires_login(session_data:)
            @view.session[:public_plan_save_data] = session_data
            @view.logger.info("💾 [PublicPlanWizardSaveDispatchHtmlPresenter] Saved to session: #{session_data.inspect}")
            @view.redirect_to @view.auth_login_path, notice: I18n.t("public_plans.save.login_required")
          end
        end
      end
    end
  end
end
