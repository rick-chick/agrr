# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 公開プラン保存: 参照農作業をユーザー農作業として確保する。
      class PlanSaveEnsureUserAgriculturalTasksInteractor
        def initialize(read_gateway:, user_agricultural_task_gateway:, logger:, translator:)
          @read_gateway = read_gateway
          @user_agricultural_task_gateway = user_agricultural_task_gateway
          @logger = logger
          @translator = translator
        end

        # @param input_dto [Dtos::PlanSaveEnsureUserAgriculturalTasksInput]
        # @return [Dtos::PlanSaveEnsureUserAgriculturalTasksOutput]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def call(input_dto)
          if input_dto.reference_crop_ids.empty?
            return empty_output
          end

          reference_crop_ids = input_dto.reference_crop_ids
          rows = @read_gateway.list_agricultural_task_reference_rows(region: input_dto.region)

          user_agricultural_task_ids = []
          skipped_agricultural_task_ids = []
          reference_agricultural_task_id_to_user_task_id = {}

          rows.each do |row|
            next unless row_intersects_plan_crops?(row, reference_crop_ids)

            existing = @user_agricultural_task_gateway.find_by_user_id_and_source_agricultural_task_id(
              user_id: input_dto.user_id,
              source_agricultural_task_id: row.reference_agricultural_task_id
            )

            if existing
              sync_crop_task_templates!(
                row: row,
                user_task_snapshot: existing,
                reference_crop_id_to_user_crop_id: input_dto.reference_crop_id_to_user_crop_id
              )
              skipped_agricultural_task_ids << existing.id
              user_agricultural_task_ids << existing.id
              reference_agricultural_task_id_to_user_task_id[row.reference_agricultural_task_id] = existing.id
              next
            end

            created = create_user_agricultural_task!(
              input_dto: input_dto,
              row: row,
              reference_crop_id_to_user_crop_id: input_dto.reference_crop_id_to_user_crop_id
            )

            user_agricultural_task_ids << created.id
            reference_agricultural_task_id_to_user_task_id[row.reference_agricultural_task_id] = created.id
            @logger.info(
              @translator.t(
                "services.plan_save_service.messages.agricultural_task_created",
                task_name: created.name
              )
            )
          end

          Dtos::PlanSaveEnsureUserAgriculturalTasksOutput.new(
            user_agricultural_task_ids: user_agricultural_task_ids,
            skipped_agricultural_task_ids: skipped_agricultural_task_ids,
            reference_agricultural_task_id_to_user_task_id: reference_agricultural_task_id_to_user_task_id
          )
        end

        private

        def empty_output
          Dtos::PlanSaveEnsureUserAgriculturalTasksOutput.new(
            user_agricultural_task_ids: [],
            skipped_agricultural_task_ids: [],
            reference_agricultural_task_id_to_user_task_id: {}
          )
        end

        def row_intersects_plan_crops?(row, reference_crop_ids)
          (row.linked_reference_crop_ids & reference_crop_ids).any?
        end

        def create_user_agricultural_task!(input_dto:, row:, reference_crop_id_to_user_crop_id:)
          attributes = Mappers::PlanSaveAgriculturalTaskAttributesMapper.attributes_for_create(
            row: row,
            region: input_dto.region
          )

          created = @user_agricultural_task_gateway.create(
            user_id: input_dto.user_id,
            attributes: attributes
          )

          sync_crop_task_templates!(
            row: row,
            user_task_snapshot: created,
            reference_crop_id_to_user_crop_id: reference_crop_id_to_user_crop_id
          )

          created
        end

        def sync_crop_task_templates!(row:, user_task_snapshot:, reference_crop_id_to_user_crop_id:)
          row.template_links.each do |link_row|
            user_crop_id = reference_crop_id_to_user_crop_id[link_row.reference_crop_id]
            next unless user_crop_id

            existing = @user_agricultural_task_gateway.find_crop_task_template(
              crop_id: user_crop_id,
              agricultural_task_id: user_task_snapshot.id
            )
            next if existing

            attributes = Mappers::PlanSaveCropTaskTemplateAttributesMapper.attributes_for_create(
              link_row: link_row,
              task_row: row,
              user_task_name: user_task_snapshot.name
            )

            @user_agricultural_task_gateway.create_crop_task_template(
              crop_id: user_crop_id,
              agricultural_task_id: user_task_snapshot.id,
              attributes: attributes
            )
          end
        end
      end
    end
  end
end
