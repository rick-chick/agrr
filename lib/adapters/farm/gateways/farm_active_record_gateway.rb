# frozen_string_literal: true

module Adapters
  module Farm
    module Gateways
      class FarmActiveRecordGateway < Domain::Farm::Gateways::FarmGateway
        def list
          ::Farm.all.map { |record| Domain::Farm::Entities::FarmEntity.from_model(record) }
        end

        def find_by_id(farm_id)
          farm = ::Farm.find(farm_id)
          Domain::Farm::Entities::FarmEntity.from_model(farm)
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
          raise StandardError, farm.errors.full_messages.join(', ') unless farm.save

          Domain::Farm::Entities::FarmEntity.from_model(farm)
        end

        def update(farm_id, update_input_dto)
          farm = ::Farm.find(farm_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:region] = update_input_dto.region if update_input_dto.region.present?
          attrs[:latitude] = update_input_dto.latitude if !update_input_dto.latitude.nil?
          attrs[:longitude] = update_input_dto.longitude if !update_input_dto.longitude.nil?
          raise StandardError, farm.errors.full_messages.join(', ') unless farm.update(attrs)

          Domain::Farm::Entities::FarmEntity.from_model(farm.reload)
        end

        def destroy(farm_id)
          farm = ::Farm.find(farm_id)
          DeletionUndo::Manager.schedule(
            record: farm,
            actor: farm.user,
            toast_message: I18n.t('farms.undo.toast', name: farm.display_name)
          )
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise StandardError, I18n.t('farms.flash.cannot_delete_in_use')
        rescue DeletionUndo::Error => e
          raise StandardError, e.message
        end
      end
    end
  end
end
