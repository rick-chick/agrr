# frozen_string_literal: true

module Adapters
  module Field
    module Gateways
      class FieldActiveRecordGateway < Domain::Field::Gateways::FieldGateway
        attr_accessor :translator

        def initialize(farm_gateway:, deletion_undo_gateway:, translator:)
          @farm_gateway = farm_gateway
          @deletion_undo_gateway = deletion_undo_gateway
          @translator = translator
        end

        def get_total_area_by_farm_id(farm_id:)
          ::Field.where(farm_id: farm_id).sum(:area).to_f
        end

        def farm_fields_list(farm_id)
          farm = find_farm_model!(farm_id)
          farm_entity = @farm_gateway.find_by_id(farm_id)
          fields = farm.fields.map { |record| Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(record) }
          Domain::Field::Results::FarmFieldsList.new(farm: farm_entity, fields: fields)
        end

        def field_with_farm(field_id)
          field_entity = field_entity_from_id(field_id)
          farm_entity = @farm_gateway.find_by_id(field_entity.farm_id)
          Domain::Field::Results::FieldWithFarm.new(farm: farm_entity, field: field_entity)
        end

        def create(create_input_dto, farm_id, farm_access_filter: nil)
          user = farm_access_filter&.user || raise(ArgumentError, "farm_access_filter required for create")
          farm = ::Farm.find(farm_id)
          attrs = {
            name: create_input_dto.name,
            area: create_input_dto.area,
            daily_fixed_cost: create_input_dto.daily_fixed_cost,
            region: create_input_dto.region
          }
          field = build_field_for_create(user, farm, attrs)
          raise Domain::Shared::Exceptions::RecordInvalid, field.errors.full_messages.join(", ") unless field.save

          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(field)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Farm not found"
        end

        def update(field_id, update_input_dto, farm_access_filter: nil)
          field = find_field_model!(field_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:area] = update_input_dto.area if !update_input_dto.area.nil?
          attrs[:daily_fixed_cost] = update_input_dto.daily_fixed_cost if !update_input_dto.daily_fixed_cost.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?
          raise Domain::Shared::Exceptions::RecordInvalid, field.errors.full_messages.join(", ") unless field.update(attrs)

          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(field.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Field not found"
        end

        def delete(field_id)
          field = find_field_model!(field_id)
          ::Adapters::DeletionUndo::Manager.schedule(
            record: field,
            actor: Adapters::Shared::UserActorResolver.user_for_deleted_by(field.user),
            toast_message: @translator.t("fields.undo.toast", name: field.display_name),
            metadata: {
              farm_id: field.farm_id
            }
          )
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Field not found"
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError, Domain::Shared::Exceptions::AssociationInUse
          raise Domain::Shared::Exceptions::AssociationInUse
        end

        private

        def field_entity_from_id(field_id)
          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(find_field_model!(field_id))
        end

        def find_field_model!(id)
          ::Field.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def find_farm_model!(id)
          ::Farm.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def build_field_for_create(user, farm, attrs)
          attributes = Domain::Field::Policies::FieldCreateAttributes.merge_for_build(
            user_id: user.id,
            farm_id: farm.id,
            attrs: attrs.to_h
          )
          ::Field.new(attributes)
        end

      end
    end
  end
end
