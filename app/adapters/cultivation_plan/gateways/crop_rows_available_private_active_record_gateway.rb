# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CropRowsAvailablePrivateActiveRecordGateway < Domain::CultivationPlan::Gateways::CropRowsAvailableGateway
        def initialize(crop_gateway:, user_lookup:, logger:)
          @crop_gateway = crop_gateway
          @user_lookup = user_lookup
          @logger = logger
        end

        # farm_region は private 一覧では不使用
        def list_by_farm_region(auth:, farm_region: nil)
          user = @user_lookup.find(auth.user_id)
          filter = Domain::Shared::Policies::CropPolicy.index_list_filter(user)
          crops = @crop_gateway.list_index_for_filter(filter).sort_by(&:name)
          rows_from_entities(crops)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[CropRowsAvailablePrivate] #{e.message}")
          []
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.error("[CropRowsAvailablePrivate] record_invalid: #{e.message}")
          []
        rescue StandardError => e
          @logger.error("[CropRowsAvailablePrivate] #{e.message}")
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
