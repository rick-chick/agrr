# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST 計画 read（表ごと）。複合は Interactor + domain mapper。
      class CultivationPlanRestPlanReadGateway
        # @return [Dtos::CultivationPlanRestPlanHeaderSnapshot]
        def find_plan_header_snapshot_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @return [Array<Dtos::CultivationPlanRestPlanFieldRowSnapshot>]
        def list_rest_plan_field_row_snapshots_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @return [Array<Dtos::CultivationPlanRestPlanCropRowSnapshot>]
        def list_rest_plan_crop_row_snapshots_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @return [Array<Dtos::CultivationPlanRestPlanCultivationRowSnapshot>]
        def list_rest_plan_cultivation_row_snapshots_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @return [Array<Integer>]
        def list_palette_crop_ids_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
