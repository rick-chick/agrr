# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      module Html
        # 公開プランをユーザーに保存した結果を HTML（リダイレクト・フラッシュ）へ写す。
        class PublicPlanSaveFromSessionHtmlPresenter < Domain::CultivationPlan::Ports::PublicPlanSaveFromSessionOutputPort
          def initialize(view:, clear_stashed_save_data_on_success: false)
            @view = view
            @clear_stashed_save_data_on_success = clear_stashed_save_data_on_success
          end

          def on_success
            @view.session.delete(:public_plan_save_data) if @clear_stashed_save_data_on_success
            @view.redirect_to @view.plans_path, notice: I18n.t("public_plans.save.success")
          end

          def on_failure(failure)
            alert = failure.message
            alert = I18n.t("public_plans.save.error") if alert.nil? || alert.to_s.empty?
            @view.redirect_to @view.public_plans_results_path, alert: alert
          end
        end
      end
    end
  end
end
