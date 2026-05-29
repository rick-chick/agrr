# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 認証ユーザーに属する単一私有計画のサマリ（id / name / status）。
      class PrivateOwnedPlanDetailInteractor
        def initialize(
          output_port:,
          user_id:,
          private_read_gateway:,
          cultivation_plan_gateway:,
          crop_gateway:,
          translator:,
          logger:,
          user_lookup:
        )
          @output_port = output_port
          @user_id = user_id
          @private_read_gateway = private_read_gateway
          @cultivation_plan_gateway = cultivation_plan_gateway
          @crop_gateway = crop_gateway
          @translator = translator
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(plan_id:)
          user = @user_lookup.find(@user_id)
          plan_id = plan_id.to_i
          rest_plan_snapshot = @private_read_gateway.find_plan_read_snapshot_by_plan_id(plan_id: plan_id)
          snapshot = Mappers::PrivatePlanReadSnapshotMapper.from_snapshot(rest_plan_snapshot)
          plan = @cultivation_plan_gateway.find_by_id(plan_id)
          if Policies::PrivateCultivationPlanAccessPolicy.access_denied?(plan: plan, user_id: user.id)
            raise Domain::Shared::Exceptions::RecordNotFound, "Cultivation plan not found"
          end

          filter = Domain::Shared::Policies::CropPolicy.index_list_filter(user)
          palette_crop_entities = @crop_gateway.list_index_for_filter(filter).sort_by(&:name)
          detail = Mappers::PrivatePlanDetailMapper.to_detail(
            snapshot: snapshot,
            palette_crop_entities: palette_crop_entities
          )
          @output_port.on_success(detail)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[PrivateOwnedPlanDetailInteractor] #{e.class}: #{e.message}")
          @output_port.on_not_found
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        rescue Domain::Shared::Exceptions::PersistenceFailed => e
          @logger.error("[PrivateOwnedPlanDetailInteractor] #{e.class}: #{e.message}")
          raise
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.warn("[PrivateOwnedPlanDetailInteractor] #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
