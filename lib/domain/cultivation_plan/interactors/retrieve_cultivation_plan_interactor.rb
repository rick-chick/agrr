# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class RetrieveCultivationPlanInteractor
        def initialize(
          output_port:,
          plan_gateway:,
          workbench_read_gateway:,
          available_crop_rows_gateway:,
          logger:
        )
          @output_port = output_port
          @plan_gateway = plan_gateway
          @workbench_read_gateway = workbench_read_gateway
          @available_crop_rows_gateway = available_crop_rows_gateway
          @logger = logger
        end

        def call(auth:, plan_id:)
          plan = @plan_gateway.find_by_id(plan_id)
          if RestPlanAccess.access_denied?(plan: plan, auth: auth)
            return @output_port.on_not_found
          end

          rest_plan_snapshot = @workbench_read_gateway.load_rest_plan_snapshot_by_plan_id(plan_id: plan_id)
          available_crop_rows = @available_crop_rows_gateway.list_by_farm_region(
            auth: auth,
            farm_region: rest_plan_snapshot.farm_region
          )
          snapshot = Mappers::CultivationPlanWorkbenchSnapshotMapper.from_snapshots(
            rest_plan_snapshot: rest_plan_snapshot,
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
