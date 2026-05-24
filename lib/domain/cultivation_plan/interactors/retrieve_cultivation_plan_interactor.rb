# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class RetrieveCultivationPlanInteractor
        def initialize(
          output_port:,
          workbench_read_gateway:,
          available_crop_rows_gateway:,
          logger:
        )
          @output_port = output_port
          @workbench_read_gateway = workbench_read_gateway
          @available_crop_rows_gateway = available_crop_rows_gateway
          @logger = logger
        end

        def call(auth:, plan_id:)
          rows = @workbench_read_gateway.load_rows(auth: auth, plan_id: plan_id)
          available_crop_rows = @available_crop_rows_gateway.list_by_farm_region(
            auth: auth,
            farm_region: rows.farm_region
          )
          snapshot = Mappers::CultivationPlanWorkbenchSnapshotMapper.to_snapshot(
            rows: rows,
            available_crop_rows: available_crop_rows
          )
          @output_port.on_success(snapshot: snapshot)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_not_found
        rescue StandardError => e
          @logger.error "❌ [Data] Error: #{e.message}"
          @output_port.on_unexpected(message: e.message)
        end
      end
    end
  end
end
