# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CropRowsAvailablePublicActiveRecordGateway < Domain::CultivationPlan::Gateways::CropRowsAvailableGateway
        def initialize(crop_gateway:, logger:)
          @crop_gateway = crop_gateway
          @logger = logger
        end

        # 公開一覧は farm_region に依存（auth は呼び出し側で渡すのみ）。
        def list_by_farm_region(auth:, farm_region: nil)
          crops = @crop_gateway.list_reference_crop_entities(region: farm_region)
          rows_from_entities(crops)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[CropRowsAvailablePublic] #{e.message}")
          []
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.error("[CropRowsAvailablePublic] record_invalid: #{e.message}")
          []
        rescue StandardError => e
          @logger.error("[CropRowsAvailablePublic] #{e.message}")
          []
        end

        private

        def rows_from_entities(crops)
          crops.map do |c|
            Domain::CultivationPlan::Dtos::CropRowsAvailableRow.new(
              id: c.id,
              name: c.name,
              variety: c.variety,
              area_per_unit: c.area_per_unit
            )
          end
        end
      end
    end
  end
end
