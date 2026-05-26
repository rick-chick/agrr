# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 公開プラン保存: 参照計画の作物をユーザー作物として確保する。
      class PlanSaveEnsureUserCropsInteractor
        def initialize(
          read_gateway:,
          user_crop_gateway:,
          crop_gateway:,
          logger:,
          translator:
        )
          @read_gateway = read_gateway
          @user_crop_gateway = user_crop_gateway
          @crop_gateway = crop_gateway
          @logger = logger
          @translator = translator
        end

        # @param input_dto [Dtos::PlanSaveEnsureUserCropsInput]
        # @return [Dtos::PlanSaveEnsureUserCropsOutput]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def call(input_dto)
          raise Domain::Shared::Exceptions::RecordInvalid, "plan_id is required to derive crops" if input_dto.plan_id.zero?

          reference_rows = @read_gateway.list_crop_reference_rows(plan_id: input_dto.plan_id)

          user_crop_ids = []
          skipped_crop_ids = []
          reference_crop_id_to_user_crop_id = {}
          ref_cpc_id_to_user_crop_id = {}
          stage_copy_pairs = []

          reference_rows.each do |row|
            existing = @user_crop_gateway.find_by_user_id_and_source_crop_id(
              user_id: input_dto.user_id,
              source_crop_id: row.reference_crop_id
            )

            if existing
              skipped_crop_ids << existing.id
              user_crop_ids << existing.id
              reference_crop_id_to_user_crop_id[row.reference_crop_id] = existing.id
              ref_cpc_id_to_user_crop_id[row.cultivation_plan_crop_id] = existing.id
              next
            end

            enforce_crop_create_limit!(user_id: input_dto.user_id)

            created = @user_crop_gateway.create(
              user_id: input_dto.user_id,
              attributes: crop_attributes_from_row(row)
            )

            user_crop_ids << created.id
            reference_crop_id_to_user_crop_id[row.reference_crop_id] = created.id
            ref_cpc_id_to_user_crop_id[row.cultivation_plan_crop_id] = created.id
            stage_copy_pairs << Dtos::PlanSaveCropStageCopyPair.new(
              reference_crop_id: row.reference_crop_id,
              new_crop_id: created.id
            )
          end

          @logger.info(
            @translator.t(
              "services.plan_save_service.debug.user_crops_created",
              count: user_crop_ids.count
            )
          )

          Dtos::PlanSaveEnsureUserCropsOutput.new(
            user_crop_ids: user_crop_ids,
            skipped_crop_ids: skipped_crop_ids,
            reference_crop_id_to_user_crop_id: reference_crop_id_to_user_crop_id,
            ref_cpc_id_to_user_crop_id: ref_cpc_id_to_user_crop_id,
            stage_copy_pairs: stage_copy_pairs,
            reference_crop_groups: reference_crop_groups_from_rows(reference_rows)
          )
        end

        private

        def reference_crop_groups_from_rows(rows)
          groups = []
          rows.each do |row|
            groups << row.name if row.name.present?
            groups.concat(Array(row.groups)) if row.groups.present?
          end
          groups.compact.uniq
        end

        def crop_attributes_from_row(row)
          {
            name: row.name,
            variety: row.variety,
            area_per_unit: row.area_per_unit,
            revenue_per_area: row.revenue_per_area,
            groups: row.groups,
            is_reference: false,
            region: row.region,
            source_crop_id: row.reference_crop_id
          }
        end

        def enforce_crop_create_limit!(user_id:)
          existing_count = @crop_gateway.count_user_owned_non_reference_crops(user_id:)
          return unless Domain::Crop::Policies::CropCreateLimitPolicy.limit_exceeded?(
            existing_non_reference_count: existing_count,
            is_reference: false
          )

          raise Domain::Shared::Exceptions::RecordInvalid,
                @translator.t("activerecord.errors.models.crop.attributes.user.crop_limit_exceeded")
        end
      end
    end
  end
end
