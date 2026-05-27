# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 公開プラン保存: 参照害虫をユーザー害虫として確保する。
      class PlanSaveEnsureUserPestsInteractor
        CreateResult = Struct.new(:id, :name, :skipped_reuse, keyword_init: true)

        def initialize(read_gateway:, user_pest_gateway:, logger:, translator:)
          @read_gateway = read_gateway
          @user_pest_gateway = user_pest_gateway
          @logger = logger
          @translator = translator
        end

        # @param input_dto [Dtos::PlanSaveEnsureUserPestsInput]
        # @return [Dtos::PlanSaveEnsureUserPestsOutput]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def call(input_dto)
          if input_dto.reference_crop_ids.empty?
            return empty_output
          end

          reference_crop_ids = input_dto.reference_crop_ids
          rows = @read_gateway.list_pest_reference_rows(
            plan_id: input_dto.plan_id,
            region: input_dto.region
          )

          user_pest_ids = []
          skipped_pest_ids = []
          reference_pest_id_to_user_pest_id = {}

          rows.each do |row|
            next unless row_intersects_plan_crops?(row, reference_crop_ids)

            existing = @user_pest_gateway.find_by_user_id_and_source_pest_id(
              user_id: input_dto.user_id,
              source_pest_id: row.reference_pest_id
            )

            if existing
              sync_crop_pest_links!(
                row: row,
                user_pest_id: existing.id,
                reference_crop_id_to_user_crop_id: input_dto.reference_crop_id_to_user_crop_id
              )
              skipped_pest_ids << existing.id
              user_pest_ids << existing.id
              reference_pest_id_to_user_pest_id[row.reference_pest_id] = existing.id
              next
            end

            user_pest = create_user_pest_with_children!(
              input_dto: input_dto,
              row: row,
              reference_crop_id_to_user_crop_id: input_dto.reference_crop_id_to_user_crop_id
            )

            user_pest_ids << user_pest.id
            skipped_pest_ids << user_pest.id if user_pest.skipped_reuse
            reference_pest_id_to_user_pest_id[row.reference_pest_id] = user_pest.id
            unless user_pest.skipped_reuse
              @logger.info(
                @translator.t(
                  "services.plan_save_service.messages.pest_created",
                  pest_name: user_pest.name
                )
              )
            end
          end

          Dtos::PlanSaveEnsureUserPestsOutput.new(
            user_pest_ids: user_pest_ids,
            skipped_pest_ids: skipped_pest_ids,
            reference_pest_id_to_user_pest_id: reference_pest_id_to_user_pest_id
          )
        end

        private

        def empty_output
          Dtos::PlanSaveEnsureUserPestsOutput.new(
            user_pest_ids: [],
            skipped_pest_ids: [],
            reference_pest_id_to_user_pest_id: {}
          )
        end

        def row_intersects_plan_crops?(row, reference_crop_ids)
          (row.linked_reference_crop_ids & reference_crop_ids).any?
        end

        def sync_crop_pest_links!(row:, user_pest_id:, reference_crop_id_to_user_crop_id:)
          row.linked_reference_crop_ids.each do |reference_crop_id|
            user_crop_id = reference_crop_id_to_user_crop_id[reference_crop_id]
            next unless user_crop_id

            @user_pest_gateway.link_crop_pest(crop_id: user_crop_id, pest_id: user_pest_id)
          end
        end

        def create_user_pest_with_children!(input_dto:, row:, reference_crop_id_to_user_crop_id:)
          attributes = Mappers::PlanSavePestAttributesMapper.attributes_for_create(
            row: row,
            region: input_dto.region
          )

          begin
            created = @user_pest_gateway.create(
              user_id: input_dto.user_id,
              attributes: attributes
            )
          rescue Domain::Shared::Exceptions::RecordInvalid => e
            raise e unless uniqueness_violation?(e.message)

            existing = @user_pest_gateway.find_by_user_id_and_source_pest_id(
              user_id: input_dto.user_id,
              source_pest_id: row.reference_pest_id
            )
            unless existing
              raise Domain::Shared::Exceptions::RecordInvalid,
                    "Pest uniqueness constraint violation but existing pest not found: " \
                    "source_pest_id=#{row.reference_pest_id}, user_id=#{input_dto.user_id}, " \
                    "error_messages=#{e.message}"
            end

            sync_crop_pest_links!(
              row: row,
              user_pest_id: existing.id,
              reference_crop_id_to_user_crop_id: reference_crop_id_to_user_crop_id
            )
            return pest_result(existing, skipped_reuse: true)
          end

          copy_child_records!(pest_id: created.id, row: row)
          sync_crop_pest_links!(
            row: row,
            user_pest_id: created.id,
            reference_crop_id_to_user_crop_id: reference_crop_id_to_user_crop_id
          )
          pest_result(created, skipped_reuse: false)
        end

        def pest_result(pest, skipped_reuse:)
          CreateResult.new(id: pest.id, name: pest.name, skipped_reuse: skipped_reuse)
        end

        def copy_child_records!(pest_id:, row:)
          if row.temperature_profile
            profile = row.temperature_profile
            @user_pest_gateway.create_temperature_profile(
              pest_id: pest_id,
              attributes: {
                base_temperature: profile.base_temperature,
                max_temperature: profile.max_temperature
              }
            )
          end

          if row.thermal_requirement
            thermal = row.thermal_requirement
            @user_pest_gateway.create_thermal_requirement(
              pest_id: pest_id,
              attributes: {
                required_gdd: thermal.required_gdd,
                first_generation_gdd: thermal.first_generation_gdd
              }
            )
          end

          row.control_methods.each do |method|
            @user_pest_gateway.create_control_method(
              pest_id: pest_id,
              attributes: {
                method_type: method.method_type,
                method_name: method.method_name,
                description: method.description,
                timing_hint: method.timing_hint
              }
            )
          end
        end

        def uniqueness_violation?(message)
          text = message.to_s
          return true if text.include?("source_pest_id") && (
            text.include?("すでに存在") || text.include?("already") || text.include?("taken")
          )

          (text.include?("Pest") || text.include?("pest")) &&
            (text.include?("すでに存在") || text.include?("already") || text.include?("taken"))
        end
      end
    end
  end
end
