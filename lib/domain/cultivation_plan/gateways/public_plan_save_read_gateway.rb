# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 公開プラン保存の読取専用（認可・組み立ては Interactor + domain mapper）。
      class PublicPlanSaveReadGateway
        # @return [Dtos::PublicPlanSaveHeaderSnapshot, nil]
        def find_header(plan_id:)
          raise NotImplementedError
        end

        # @return [Array<Dtos::PublicPlanSaveFieldDatum>]
        def list_field_rows(plan_id:)
          raise NotImplementedError
        end
      end
    end
  end
end
