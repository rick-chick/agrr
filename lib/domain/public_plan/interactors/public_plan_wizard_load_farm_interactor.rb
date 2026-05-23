# frozen_string_literal: true

module Domain
  module PublicPlan
    module Interactors
      # 公開プラン HTML ウィザード: farm_id から農場エンティティを解決する（失敗時は Presenter が redirect）。
      class PublicPlanWizardLoadFarmInteractor
        def initialize(public_plan_gateway:, failure_presenter:)
          @public_plan_gateway = public_plan_gateway
          @failure_presenter = failure_presenter
        end

        # @return [Domain::Farm::Entities::FarmEntity, nil] nil のとき redirect 済み
        def call(farm_id:, alert_i18n_key:)
          farm = @public_plan_gateway.find_by_farm_id(farm_id)
          unless farm
            @failure_presenter.redirect(alert_i18n_key: alert_i18n_key)
            return nil
          end

          farm
        end
      end
    end
  end
end
