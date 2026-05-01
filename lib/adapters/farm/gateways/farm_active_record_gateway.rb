# frozen_string_literal: true

module Adapters
  module Farm
    module Gateways
      class FarmActiveRecordGateway < Domain::Farm::Gateways::FarmGateway
        attr_accessor :translator
        attr_accessor :user_id

        def initialize
          @translator = Adapters::Translators::RailsTranslator.new
        end
        def list(input_dto)
          if input_dto.is_admin
            # 管理者の場合は自分の農場と参照農場の両方を取得
            ::Farm.where("user_id = ? OR is_reference = ?", @user_id, true).map { |record| Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(record) }
          else
            # 通常ユーザーの場合は自分の農場のみ（参照農場・他ユーザー農場は含めない）
            ::Farm.where(user_id: @user_id, is_reference: false).map { |record| Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(record) }
          end
        end

        def find_by_id(farm_id)
          farm = ::Farm.find(farm_id)
          Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(farm)
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

        def destroy(farm_id)
          farm = ::Farm.find(farm_id)
          DeletionUndo::Manager.schedule(
            record: farm,
            actor: Adapters::Shared::UserActorResolver.user_for_deleted_by(farm.user),
            toast_message: @translator.t("farms.undo.toast", name: farm.display_name)
          )
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise Domain::Shared::Exceptions::AssociationInUse, @translator.t("farms.flash.cannot_delete_in_use")
        rescue DeletionUndo::Error => e
          raise StandardError, e.message
        end

        def mark_weather_data_failed(farm_id, error_msg)
          farm = ::Farm.find_by(id: farm_id)
          farm&.mark_weather_data_failed!(error_msg)
        end

        def increment_weather_data_progress(farm_id)
          farm = ::Farm.find_by(id: farm_id)
          farm&.increment_weather_data_progress!
        end

        def get_weather_data_progress(farm_id)
          farm = ::Farm.find_by(id: farm_id)
          farm&.weather_data_progress
        end

        def get_weather_data_fetched_years(farm_id)
          farm = ::Farm.find_by(id: farm_id)
          farm&.weather_data_fetched_years
        end

        def get_weather_data_total_years(farm_id)
          farm = ::Farm.find_by(id: farm_id)
          farm&.weather_data_total_years
        end

        def update_weather_location_id(farm_id, weather_location_id)
          farm = ::Farm.find_by(id: farm_id)
          farm&.update_column(:weather_location_id, weather_location_id)
        end

        def update_predicted_weather_data(farm_id, payload)
          ::Farm.find(farm_id).update!(predicted_weather_data: payload)
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

        def find_authorized_model_for_view(user, id)
          farm = find_farm_model!(id)
          unless Domain::Shared::Policies::FarmPolicy.view_allowed?(user, is_reference: farm.is_reference, user_id: farm.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          farm
        end

        def find_authorized_model_for_edit(user, id)
          farm = find_farm_model!(id)
          unless Domain::Shared::Policies::FarmPolicy.edit_allowed?(user, is_reference: farm.is_reference, user_id: farm.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          farm
        end

        def find_authorized_for_view(user, id)
          Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(find_authorized_model_for_view(user, id))
        end

        def find_authorized_for_edit(user, id)
          Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(find_authorized_model_for_edit(user, id))
        end

        def find_model(id)
          find_farm_model!(id)
        end

        def create_for_user(user, attrs)
          h = Domain::Shared::Policies::FarmPolicy.normalize_attrs_for_create(user, attrs)
          farm = ::Farm.new(h)
          raise Domain::Shared::Exceptions::RecordInvalid, farm.errors.full_messages.join(", ") unless farm.save

          Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(farm)
        end

        def update_for_user(user, id, attrs)
          farm = find_farm_model!(id)
          unless Domain::Shared::Policies::FarmPolicy.edit_allowed?(user, is_reference: farm.is_reference, user_id: farm.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          normalized = Domain::Shared::Policies::FarmPolicy.normalize_attrs_for_update(
            user,
            farm.attributes.symbolize_keys,
            attrs
          )
          raise Domain::Shared::Exceptions::RecordInvalid, farm.errors.full_messages.join(", ") unless farm.update(normalized)

          Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(farm.reload)
        end

        def detail_for_authorized_view(user, id)
          farm = find_farm_with_fields!(id)
          unless Domain::Shared::Policies::FarmPolicy.view_allowed?(user, is_reference: farm.is_reference, user_id: farm.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          Adapters::Farm::Mappers::FarmMapper.detail_dto_from_farm_record(farm)
        end

        def soft_destroy_with_undo(user:, farm_id:, auto_hide_after: 5000, translator: nil)
          translator ||= @translator
          translator ||= Adapters::Translators::RailsTranslator.new
          farm = find_farm_model!(farm_id)
          unless Domain::Shared::Policies::FarmPolicy.edit_allowed?(user, is_reference: farm.is_reference, user_id: farm.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          farm_name = farm.name
          toast_message = translator.t("flash.farms.deleted", name: farm_name)
          undo_gw = CompositionRoot.deletion_undo_gateway
          event = undo_gw.schedule(
            record: farm,
            actor: user,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after
          )
          { success: true, undo_entity: event, farm_name: farm_name }
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(e.message) }
        end

        private

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
