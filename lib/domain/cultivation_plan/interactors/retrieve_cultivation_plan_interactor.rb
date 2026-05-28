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
          base_snapshot = load_workbench_snapshot(auth: auth, plan_id: plan_id)
          if RestPlanAccess.workbench_read_access_denied?(plan_header: base_snapshot.plan, auth: auth)
            return @output_port.on_not_found
          end

          available_crop_rows = @available_crop_rows_gateway.list_by_farm_region(
            auth: auth,
            farm_region: base_snapshot.farm_region
          )

          snapshot = Dtos::CultivationPlanWorkbenchSnapshot.new(
            plan: base_snapshot.plan,
            fields: base_snapshot.fields,
            crops: base_snapshot.crops,
            cultivations: base_snapshot.cultivations,
            available_crop_rows: available_crop_rows,
            farm_region: base_snapshot.farm_region
          )
          @output_port.on_success(snapshot: snapshot)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_not_found
        rescue StandardError => e
          @logger.error "❌ [Data] Error: #{e.message}"
          @output_port.on_unexpected(message: e.message)
        end

        private

        def load_workbench_snapshot(auth:, plan_id:)
          if auth.private?
            @workbench_read_gateway.load_snapshot_by_plan_id_and_user_id(
              plan_id: plan_id,
              user_id: auth.user_id
            )
          else
            @workbench_read_gateway.load_snapshot_by_plan_id(plan_id: plan_id)
          end
        end
      end
    end
  end
end
