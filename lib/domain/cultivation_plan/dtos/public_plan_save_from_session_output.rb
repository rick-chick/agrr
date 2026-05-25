# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # PublicPlanSavePersistencePort の戻り値。Adapter は PlanSaveSession 結果をこの形へ正規化する。
      class PublicPlanSaveFromSessionOutput
        attr_reader :error_message, :new_cultivation_plan_id, :skipped_items

        def initialize(success:, error_message: nil, new_cultivation_plan_id: nil, skipped_items: nil)
          @success = success
          @error_message = error_message
          @new_cultivation_plan_id = new_cultivation_plan_id
          @skipped_items = skipped_items
        end

        def success?
          @success
        end
      end
    end
  end
end
