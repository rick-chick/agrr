# frozen_string_literal: true

module Adapters
  module Crop
    # CropAiUpsertService から移した AR 永続化（作物 AI 作成の upsert）。
    class CropAiUpsertActiveRecordPersistence
      include Domain::Crop::Ports::CropAiUpsertPersistencePort

      def initialize(crop_gateway:, create_interactor:, logger:, translator:)
        @crop_gateway = crop_gateway
        @create_interactor = create_interactor
        @logger = logger
        @translator = translator
      end

      # @param user_dto [Domain::Shared::Dtos::User]
      # @param crop_info [Hash] agrr 応答（パース済み）
      def upsert(user_dto:, crop_name:, variety:, crop_info:, crop_access_filter:)
        dummy_attrs = Domain::Crop::CropAiUpsertNormalization.normalize_attrs_for_create(user_dto, { name: "dummy" })
        dummy_crop = ::Crop.new(dummy_attrs)
        unless dummy_crop.valid?
          validation_error = dummy_crop.errors[:user].first || dummy_crop.errors[:base].first
          if validation_error
            return Domain::Shared::Dtos::HttpJsonEnvelope.new(
              status: :unprocessable_entity,
              body: { error: validation_error }
            )
          end
        end

        if crop_info["success"] == false
          error_msg = crop_info["error"] || @translator.t("api.errors.crops.fetch_failed")
          return Domain::Shared::Dtos::HttpJsonEnvelope.new(
            status: :unprocessable_entity,
            body: { error: error_msg }
          )
        end

        crop_data = crop_info["crop"]
        stage_requirements = crop_info["stage_requirements"]

        unless crop_data
          return Domain::Shared::Dtos::HttpJsonEnvelope.new(
            status: :unprocessable_entity,
            body: { error: @translator.t("api.errors.crops.invalid_payload") }
          )
        end

        crop_id = crop_data["crop_id"]
        @logger.info "📊 [AI Crop] Retrieved data: crop_id=#{crop_id}, area=#{crop_data['area_per_unit']}, revenue=#{crop_data['revenue_per_area']}, stages=#{stage_requirements&.size || 0}"

        existing_crop = find_existing_crop_for_update(user_dto, crop_id, crop_access_filter)

        if existing_crop
          update_existing_crop(existing_crop, crop_data, variety, stage_requirements)
        else
          create_new_crop(user_dto, crop_name, crop_data, variety, stage_requirements)
        end
      rescue StandardError => e
        @logger.error "❌ [AI Crop] Error in persistence: #{e.message}"
        @logger.error "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
        Domain::Shared::Dtos::HttpJsonEnvelope.new(
          status: :internal_server_error,
          body: { error: @translator.t("api.errors.crops.fetch_failed_with_reason", message: e.message) }
        )
      end

      private

      def find_existing_crop_for_update(user_dto, crop_id, crop_access_filter)
        return nil if crop_id.nil? || crop_id.to_s.strip.empty?

        begin
          entity = @crop_gateway.find_by_id(crop_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(crop_access_filter, entity)
          ::Crop.find(crop_id)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, ActiveRecord::RecordNotFound, Domain::Shared::Exceptions::RecordNotFound
          nil
        end
      end

      def update_existing_crop(existing_crop, crop_data, variety, stage_requirements)
        @logger.info "🔄 [AI Crop] Existing crop found: #{existing_crop.name} (DB_ID: #{existing_crop.id}, is_reference: #{existing_crop.is_reference})"
        @logger.info "🔄 [AI Crop] Updating crop with latest data from agrr"

        validate_stage_requirements!(stage_requirements)

        ActiveRecord::Base.transaction do
          variety_value = if variety.nil? || variety.to_s.strip.empty?
            crop_data["variety"] || existing_crop.variety
          else
            variety
          end

          existing_crop.update!(
            variety: variety_value,
            area_per_unit: crop_data["area_per_unit"],
            revenue_per_area: crop_data["revenue_per_area"],
            groups: crop_data["groups"] || []
          )

          existing_crop.crop_stages.destroy_all
          if stage_requirements.is_a?(Array) && !stage_requirements.empty?
            saved_stages = save_crop_stages(existing_crop.id, stage_requirements)
            @logger.info "🌱 [AI Crop] Updated #{saved_stages} stages for crop##{existing_crop.id}"
          end
        end

        Domain::Shared::Dtos::HttpJsonEnvelope.new(
          status: :ok,
          body: {
            success: true,
            crop_id: existing_crop.id,
            crop_name: existing_crop.name,
            variety: existing_crop.variety,
            area_per_unit: existing_crop.area_per_unit,
            revenue_per_area: existing_crop.revenue_per_area,
            stages_count: stage_requirements.is_a?(Array) ? stage_requirements.size : 0,
            is_reference: existing_crop.is_reference,
            message: @translator.t("api.messages.crops.updated_with_latest", name: existing_crop.name)
          }
        )
      end

      def create_new_crop(user_dto, crop_name, crop_data, variety, stage_requirements)
        @logger.info "🆕 [AI Crop] Creating new crop: #{crop_name} (crop_id: #{crop_data['crop_id']})"
        variety_value = if variety.nil? || variety.to_s.strip.empty?
          crop_data["variety"]
        else
          variety
        end

        base_attrs = {
          name: crop_name,
          variety: variety_value,
          area_per_unit: crop_data["area_per_unit"],
          revenue_per_area: crop_data["revenue_per_area"],
          groups: crop_data["groups"] || []
        }

        validate_stage_requirements!(stage_requirements)

        result = nil
        crop_entity = nil
        saved_stages = 0

        ActiveRecord::Base.transaction do
          attrs_for_create = Domain::Crop::CropAiUpsertNormalization.normalize_attrs_for_create(user_dto, base_attrs)

          result = @create_interactor.call(attrs_for_create)

          unless result.success?
            @logger.error "❌ [AI Crop] Failed to create: #{result.error}"
            raise ActiveRecord::Rollback
          end

          crop_entity = result.data

          if stage_requirements.is_a?(Array) && !stage_requirements.empty?
            saved_stages = save_crop_stages(crop_entity.id, stage_requirements)
          end
        end

        unless result&.success?
          return Domain::Shared::Dtos::HttpJsonEnvelope.new(
            status: :unprocessable_entity,
            body: { error: result&.error }
          )
        end

        @logger.info "✅ [AI Crop] Created crop##{crop_entity.id}: #{crop_entity.name}"
        if stage_requirements.is_a?(Array) && !stage_requirements.empty?
          @logger.info "🌱 [AI Crop] Saved #{saved_stages} stages for crop##{crop_entity.id}"
        end

        Domain::Shared::Dtos::HttpJsonEnvelope.new(
          status: :created,
          body: {
            success: true,
            crop_id: crop_entity.id,
            crop_name: crop_entity.name,
            variety: crop_entity.variety,
            area_per_unit: crop_entity.area_per_unit,
            revenue_per_area: crop_entity.revenue_per_area,
            stages_count: stage_requirements.is_a?(Array) ? stage_requirements.size : 0,
            message: @translator.t("api.messages.crops.created_by_ai", name: crop_entity.name)
          }
        )
      end

      def save_crop_stages(crop_id, stages_data)
        saved_count = 0

        stages_data.each do |stage_requirement|
          stage_info = stage_requirement["stage"]
          raise ArgumentError, "stage information is required" unless stage_info
          if stage_info["order"].nil? || stage_info["order"].to_s.strip.empty?
            raise ArgumentError, "stage order is required"
          end

          stage = ::CropStage.create!(
            crop_id: crop_id,
            name: stage_info["name"],
            order: stage_info["order"]
          )

          temp_data = stage_requirement["temperature"]
          if temp_data.is_a?(Hash) && !temp_data.empty?
            ::TemperatureRequirement.create!(
              crop_stage_id: stage.id,
              base_temperature: temp_data["base_temperature"],
              optimal_min: temp_data["optimal_min"],
              optimal_max: temp_data["optimal_max"],
              low_stress_threshold: temp_data["low_stress_threshold"],
              high_stress_threshold: temp_data["high_stress_threshold"],
              frost_threshold: temp_data["frost_threshold"],
              sterility_risk_threshold: temp_data["sterility_risk_threshold"]
            )
          end

          sunshine_data = stage_requirement["sunshine"]
          if sunshine_data.is_a?(Hash) && !sunshine_data.empty?
            ::SunshineRequirement.create!(
              crop_stage_id: stage.id,
              minimum_sunshine_hours: sunshine_data["minimum_sunshine_hours"],
              target_sunshine_hours: sunshine_data["target_sunshine_hours"]
            )
          end

          thermal_data = stage_requirement["thermal"]
          if thermal_data.is_a?(Hash) && !thermal_data.empty?
            ::ThermalRequirement.create!(
              crop_stage_id: stage.id,
              required_gdd: thermal_data["required_gdd"]
            )
          end

          nutrients_data = stage_requirement["nutrients"]
          if nutrients_data.is_a?(Hash) && !nutrients_data.empty?
            daily_uptake = nutrients_data["daily_uptake"]
            if daily_uptake.is_a?(Hash) && !daily_uptake.empty?
              ::NutrientRequirement.create!(
                crop_stage_id: stage.id,
                daily_uptake_n: daily_uptake["N"],
                daily_uptake_p: daily_uptake["P"],
                daily_uptake_k: daily_uptake["K"]
              )
            end
          end

          saved_count += 1
          @logger.debug "  🌱 Stage #{stage.order}: #{stage.name} (ID: #{stage.id})"
        end

        saved_count
      end

      def validate_stage_requirements!(stage_requirements)
        return if stage_requirements.nil? || !stage_requirements.is_a?(Array) || stage_requirements.empty?

        stage_requirements.each do |stage_requirement|
          stage_info = stage_requirement["stage"]
          raise ArgumentError, "stage information is required" unless stage_info
          if stage_info["order"].nil? || stage_info["order"].to_s.strip.empty?
            raise ArgumentError, "stage order is required"
          end
        end
      end
    end
  end
end
