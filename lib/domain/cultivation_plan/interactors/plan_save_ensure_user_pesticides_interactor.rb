# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class PlanSaveEnsureUserPesticidesInteractor
        def initialize(read_gateway:, user_pesticide_gateway:, logger:, translator:)
          @read_gateway = read_gateway
          @user_pesticide_gateway = user_pesticide_gateway
          @logger = logger
          @translator = translator
        end

        # @param input_dto [Dtos::PlanSaveEnsureUserPesticidesInput]
        # @return [Dtos::PlanSaveEnsureUserPesticidesOutput]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def call(input_dto)
          rows = @read_gateway.list_pesticide_reference_rows(region: input_dto.region)

          user_pesticide_ids = []
          skipped_pesticide_ids = []

          rows.each do |row|
            user_crop_id = input_dto.reference_crop_id_to_user_crop_id[row.reference_crop_id]
            user_pest_id = input_dto.reference_pest_id_to_user_pest_id[row.reference_pest_id]

            unless user_crop_id && user_pest_id
              @logger.warn(
                "Skipping pesticide copy due to missing crop/pest mapping " \
                "(pesticide_id=#{row.reference_pesticide_id})"
              )
              next
            end

            existing = @user_pesticide_gateway.find_by_user_id_and_source_pesticide_id(
              user_id: input_dto.user_id,
              source_pesticide_id: row.reference_pesticide_id
            )

            if existing
              skipped_pesticide_ids << existing.id
              user_pesticide_ids << existing.id
              next
            end

            attributes = Mappers::PlanSavePesticideAttributesMapper.attributes_for_create(
              row: row,
              region: input_dto.region,
              user_crop_id: user_crop_id,
              user_pest_id: user_pest_id
            )

            created = @user_pesticide_gateway.create(
              user_id: input_dto.user_id,
              attributes: attributes,
              usage_constraint_attributes: Mappers::PlanSavePesticideAttributesMapper.usage_constraint_attributes(row: row),
              application_detail_attributes: Mappers::PlanSavePesticideAttributesMapper.application_detail_attributes(row: row)
            )

            user_pesticide_ids << created.id
            @logger.info(
              @translator.t(
                "services.plan_save_service.messages.pesticide_created",
                pesticide_name: created.name
              )
            )
          end

          Dtos::PlanSaveEnsureUserPesticidesOutput.new(
            user_pesticide_ids: user_pesticide_ids,
            skipped_pesticide_ids: skipped_pesticide_ids
          )
        end
      end
    end
  end
end
