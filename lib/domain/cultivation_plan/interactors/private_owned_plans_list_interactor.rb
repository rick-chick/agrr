# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 認証ユーザーに紐づく私有計画の一覧（軽量 read）。
      class PrivateOwnedPlansListInteractor
        def initialize(output_port:, user_id:, private_read_gateway:, translator:, logger:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @private_read_gateway = private_read_gateway
          @translator = translator
          @logger = logger
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          plan_snapshots = @private_read_gateway.list_private_plan_index_plan_snapshots(user_id: user.id)
          plan_ids = plan_snapshots.map(&:id)
          crops_count_hash = @private_read_gateway.count_cultivation_plan_crops_by_plan_ids(plan_ids: plan_ids)
          fields_count_hash = @private_read_gateway.count_cultivation_plan_fields_by_plan_ids(plan_ids: plan_ids)
          plan_row_snapshots = Mappers::PrivatePlanIndexRowsMapper.plan_row_snapshots_with_counts(
            plan_snapshots,
            crops_count_hash: crops_count_hash,
            fields_count_hash: fields_count_hash
          )
          rows = Mappers::PrivatePlanIndexRowsMapper.to_index_rows(plan_row_snapshots)
          @output_port.on_success(rows)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[PrivateOwnedPlansListInteractor] #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(@translator.t("plans.errors.session_invalid")))
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        rescue Domain::Shared::Exceptions::PersistenceFailed => e
          @logger.error("[PrivateOwnedPlansListInteractor] #{e.class}: #{e.message}")
          raise
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.warn("[PrivateOwnedPlansListInteractor] #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
