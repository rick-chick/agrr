# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class PlanSaveEnsureUserFertilizesInteractor
        def initialize(read_gateway:, user_fertilize_gateway:, logger:, translator:)
          @read_gateway = read_gateway
          @user_fertilize_gateway = user_fertilize_gateway
          @logger = logger
          @translator = translator
        end

        # @param input_dto [Dtos::PlanSaveEnsureUserFertilizesInput]
        # @return [Dtos::PlanSaveEnsureUserFertilizesOutput]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def call(input_dto)
          rows = @read_gateway.list_fertilize_reference_rows(region: input_dto.region)

          user_fertilize_ids = []
          skipped_fertilize_ids = []

          rows.each do |row|
            existing = @user_fertilize_gateway.find_by_user_id_and_source_fertilize_id(
              user_id: input_dto.user_id,
              source_fertilize_id: row.reference_fertilize_id
            )

            if existing
              skipped_fertilize_ids << existing.id
              user_fertilize_ids << existing.id
              next
            end

            unique_name = resolve_unique_name(row.name)
            attributes = Mappers::PlanSaveFertilizeAttributesMapper.attributes_for_create(
              row: row,
              region: input_dto.region,
              name: unique_name
            )

            created = @user_fertilize_gateway.create(
              user_id: input_dto.user_id,
              attributes: attributes
            )

            user_fertilize_ids << created.id
            @logger.info(
              @translator.t(
                "services.plan_save_service.messages.fertilize_created",
                fertilize_name: created.name
              )
            )
          end

          Dtos::PlanSaveEnsureUserFertilizesOutput.new(
            user_fertilize_ids: user_fertilize_ids,
            skipped_fertilize_ids: skipped_fertilize_ids
          )
        end

        private

        def resolve_unique_name(base_name)
          Mappers::PlanSaveFertilizeUniqueName.each_candidate(base_name) do |candidate|
            return candidate unless @read_gateway.exists_fertilize_name?(name: candidate)
          end
        end
      end
    end
  end
end
