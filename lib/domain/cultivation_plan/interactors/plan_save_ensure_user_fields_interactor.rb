# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 公開プラン保存: ユーザー圃場を確保（再利用時は既存、否则 session field_data から作成）。
      class PlanSaveEnsureUserFieldsInteractor
        def initialize(plan_save_field_gateway:, logger:, translator:)
          @gateway = plan_save_field_gateway
          @logger = logger
          @translator = translator
        end

        # @param input_dto [Dtos::PlanSaveEnsureUserFieldsInput]
        # @return [Dtos::PlanSaveEnsureUserFieldsOutput]
        def call(input_dto)
          if input_dto.farm_reused
            return ensure_reused_fields(input_dto)
          end

          ensure_created_fields(input_dto)
        end

        private

        def ensure_reused_fields(input_dto)
          @logger.info("♻️ [PlanSaveService] Skipping field creation because farm was reused")
          existing = @gateway.list_by_farm_id(
            farm_id: input_dto.farm_id,
            user_id: input_dto.user_id
          )
          ids = existing.map { |f| f.id }
          Dtos::PlanSaveEnsureUserFieldsOutput.new(
            field_ids: ids,
            skipped_field_ids: ids
          )
        end

        def ensure_created_fields(input_dto)
          if input_dto.field_data.empty?
            @logger.debug(
              @translator.t(
                "services.plan_save_service.debug.field_data_extracted",
                field_data: [].inspect
              )
            )
            return Dtos::PlanSaveEnsureUserFieldsOutput.new(field_ids: [], skipped_field_ids: [])
          end

          @logger.debug(
            @translator.t(
              "services.plan_save_service.debug.field_data_extracted",
              field_data: input_dto.field_data.map(&:to_session_row).inspect
            )
          )

          created_ids = []
          input_dto.field_data.each do |datum|
            @logger.debug(
              "🔍 [PlanSaveService] Processing field_info: #{datum.to_session_row.inspect}"
            )
            attrs = Mappers::PlanSaveFieldCreateAttributesMapper.attributes_for_create(
              datum: datum,
              translator: @translator
            )
            @logger.debug("🔍 [PlanSaveService] Creating field with attrs: #{attrs.inspect}")

            created = @gateway.create(
              farm_id: input_dto.farm_id,
              user_id: input_dto.user_id,
              attributes: attrs
            )
            created_ids << created.id
            @logger.info(
              @translator.t(
                "services.plan_save_service.messages.field_created",
                field_name: attrs[:name]
              )
            )
          end

          @logger.info(
            @translator.t(
              "services.plan_save_service.debug.user_fields_created",
              count: created_ids.count
            )
          )

          Dtos::PlanSaveEnsureUserFieldsOutput.new(
            field_ids: created_ids,
            skipped_field_ids: []
          )
        end
      end
    end
  end
end
