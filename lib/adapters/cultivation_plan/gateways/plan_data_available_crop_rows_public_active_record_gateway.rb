# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PlanDataAvailableCropRowsPublicActiveRecordGateway < Domain::CultivationPlan::Gateways::PlanDataAvailableCropRowsGateway
        def initialize(crop_gateway:, logger:)
          @crop_gateway = crop_gateway
          @logger = logger
        end

        # 公開一覧は farm_region に依存（auth は呼び出し側で渡すのみ）。
        def rows(auth:, farm_region: nil)
          crops = @crop_gateway.list_reference_crop_entities(region: farm_region)
          crops = @crop_gateway.list_reference_crop_entities(region: farm_region)
          rows_from_entities(crops)
        rescue StandardError => e
          @logger.error("[PlanDataAvailableCropRowsPublic] #{e.message}")
          []
        end

        private

        def rows_from_entities(crops)
          crops.map { |c| { id: c.id, name: c.name, variety: c.variety, area_per_unit: c.area_per_unit } }
        end
      end
    end
  end
end
