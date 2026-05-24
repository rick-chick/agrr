# frozen_string_literal: true

module Adapters
  module Farm
    module Gateways
      class FarmActiveRecordGateway < Domain::Farm::Gateways::FarmGateway
        def initialize(deletion_undo_gateway:)
          @deletion_undo_gateway = deletion_undo_gateway
        end
        def list_user_owned_farms(user_id:)
          ::Farm.where(user_id: user_id, is_reference: false).map { |record| Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(record) }
        end

        def list_user_and_reference_farms(user_id:)
          ::Farm.where("user_id = ? OR is_reference = ?", user_id, true).map { |record| Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(record) }
        end

        def list_reference_farms
          list_reference_farms_for_region(nil)
        end

        def find_by_id(farm_id, include_weather_data_fields: false)
          farm = ::Farm.find(farm_id)
          Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(
            farm,
            include_weather_data_fields: include_weather_data_fields
          )
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def create(create_input_dto)
          farm = ::Farm.new(
            name: create_input_dto.name,
            region: create_input_dto.region,
            latitude: create_input_dto.latitude,
            longitude: create_input_dto.longitude,
            user_id: create_input_dto.user_id,
            is_reference: create_input_dto.is_reference || false
          )
          raise Domain::Shared::Exceptions::RecordInvalid, farm.errors.full_messages.join(", ") unless farm.save

          Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(farm)
        end

        def update(farm_id, update_input_dto)
          farm = ::Farm.find(farm_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:region] = update_input_dto.region if update_input_dto.region.present?
          attrs[:latitude] = update_input_dto.latitude if !update_input_dto.latitude.nil?
          attrs[:longitude] = update_input_dto.longitude if !update_input_dto.longitude.nil?
          raise Domain::Shared::Exceptions::RecordInvalid, farm.errors.full_messages.join(", ") unless farm.update(attrs)

          Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(farm.reload)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def update_weather_progress(farm_id, attrs)
          farm = ::Farm.find(farm_id)
          raise Domain::Shared::Exceptions::RecordInvalid, farm.errors.full_messages.join(", ") unless farm.update(attrs.to_h.symbolize_keys)

          Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(farm.reload, include_weather_data_fields: true)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def update_weather_location_id(farm_id, weather_location_id)
          farm = ::Farm.find_by(id: farm_id)
          farm&.update_column(:weather_location_id, weather_location_id)
        end

        def update_predicted_weather_data(farm_id, payload)
          ::Farm.find(farm_id).update!(predicted_weather_data: Domain::WeatherData::Dtos::PredictedWeatherSnapshot.storage_column_value(payload))
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.message
        end

        def list_reference_farms_for_region(region)
          scope = ::Farm.reference
          scope = scope.where(region: region) if region.present?
          scope.map { |record| Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(record) }
        end

        def user_owned_records(user)
          ::Farm.user_owned.by_user(user)
        end

        def count_user_owned_non_reference_farms(user_id:)
          ::Farm.where(user_id: user_id, is_reference: false).count
        end

        def create_for_user(user, attrs)
          farm = ::Farm.new(attrs.to_h.symbolize_keys)
          raise Domain::Shared::Exceptions::RecordInvalid, farm.errors.full_messages.join(", ") unless farm.save

          Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(farm)
        end

        def update_for_user(_user, id, attrs)
          farm = find_farm_model!(id)
          raise Domain::Shared::Exceptions::RecordInvalid, farm.errors.full_messages.join(", ") unless farm.update(attrs.to_h.symbolize_keys)

          Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(farm.reload)
        end

        def farm_detail_with_fields(id)
          farm = find_farm_with_fields!(id)
          Adapters::Farm::Mappers::FarmMapper.detail_dto_from_farm_record(farm)
        end

        def find_delete_usage(farm_id)
          farm = find_farm_model!(farm_id)
          Domain::Farm::Dtos::FarmDeleteUsage.new(
            free_crop_plans_count: farm.free_crop_plans.count
          )
        end

        def soft_delete_with_undo(user:, farm_id:, auto_hide_after: 5000, toast_message:)
          farm = find_farm_model!(farm_id)
          farm_name = farm.name
          event = @deletion_undo_gateway.schedule(
            resource_type: farm.class.name,
            resource_id: farm.id,
            actor_id: user.id,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after
          )
          { success: true, undo_entity: event, farm_name: farm_name }
        rescue Domain::Shared::Exceptions::RecordNotFound
          raise
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          { success: false, error_dto: Domain::Shared::Dtos::Error.new(e.message) }
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::Error.new(e.message) }
        end

        def farm_region_for_wizard_lookup_by_id(farm_id)
          return nil if farm_id.blank?

          ::Farm.find_by(id: farm_id)&.region
        end

        def farm_weather_data_access_context_for_owned_farm(user_id:, farm_id:)
          record = ::Farm.find_by(id: farm_id, user_id: user_id)
          farm_weather_data_access_context_from_record(record)
        end

        def farm_weather_data_access_context_for_admin_lookup(farm_id:)
          record = ::Farm.find_by(id: farm_id)
          farm_weather_data_access_context_from_record(record)
        end

        private

        def farm_weather_data_access_context_from_record(record)
          return nil unless record

          Domain::Farm::Dtos::FarmWeatherDataAccessContext.new(
            farm_id: record.id,
            display_name: record.display_name,
            latitude: record.latitude,
            longitude: record.longitude,
            weather_location_id: record.weather_location_id,
            predicted_weather_data: record.predicted_weather_data
          )
        end

        def find_farm_with_fields!(id)
          ::Farm.includes(:fields).find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def find_farm_model!(id)
          ::Farm.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
