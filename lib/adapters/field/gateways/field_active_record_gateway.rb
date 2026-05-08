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

        def authorized_farm_fields_list(farm_id, user_id)
          farm_entity, fields = farm_entity_and_field_entities_for_farm_list!(farm_id, user_id)
          Domain::Field::Results::FarmFieldsList.new(farm: farm_entity, fields: fields)
        end

        def field_with_farm_for_user(field_id, user_id)
          field_entity = find_by_id_and_user(field_id, user_id)
          user = find_user!(user_id)
          farm_entity = @farm_gateway.find_authorized_for_edit(user, field_entity.farm_id)
          Domain::Field::Results::FieldWithFarm.new(farm: farm_entity, field: field_entity)
        end

        def find_by_id_and_user(field_id, user_id)
          user = ::User.find(user_id)
          record = FieldPolicy.find_owned!(user, field_id)
          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(record)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied, ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Field not found"
        end

        def create(create_input_dto, farm_id, user_id)
          user = ::User.find(user_id)
          @farm_gateway.find_authorized_for_edit(user, farm_id)
          farm = ::Farm.find(farm_id)
          attrs = {
            name: create_input_dto.name,
            area: create_input_dto.area,
            daily_fixed_cost: create_input_dto.daily_fixed_cost,
            region: create_input_dto.region
          }
          field = FieldPolicy.build_for_create(user, farm, attrs)
          raise Domain::Shared::Exceptions::RecordInvalid, field.errors.full_messages.join(", ") unless field.save

          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(field)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied, ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Farm not found"
        end

        def update(field_id, update_input_dto, user_id)
          user = ::User.find(user_id)
          field = FieldPolicy.find_owned!(user, field_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:area] = update_input_dto.area if !update_input_dto.area.nil?
          attrs[:daily_fixed_cost] = update_input_dto.daily_fixed_cost if !update_input_dto.daily_fixed_cost.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?
          raise Domain::Shared::Exceptions::RecordInvalid, field.errors.full_messages.join(", ") unless field.update(attrs)

          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(field.reload)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied, ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Field not found"
        end

        def destroy(field_id, user_id)
          user = ::User.find(user_id)
          field = FieldPolicy.find_owned!(user, field_id)
          ::DeletionUndo::Manager.schedule(
            record: field,
            actor: Adapters::Shared::UserActorResolver.user_for_deleted_by(user),
            toast_message: @translator.t("fields.undo.toast", name: field.display_name),
            metadata: {
              farm_id: field.farm_id
            }
          )
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied, ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Field not found"
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError, Domain::Shared::Exceptions::AssociationInUse
          raise Domain::Shared::Exceptions::AssociationInUse, @translator.t("fields.flash.cannot_delete_in_use")
        end

        def find_authorized_for_view(user, id)
          field = find_field_model!(id)
          unless field_view_allowed?(user, field)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(field)
        end

        def find_authorized_for_edit(user, id)
          field = find_field_model!(id)
          unless field_edit_allowed?(user, field)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(field)
        end

        def find_authorized_field_loaded_in_farm!(user, farm_id, field_id)
          bundle = @farm_gateway.find_authorized_farm_loaded_bundle!(user, farm_id, for_edit: true)
          farm = bundle.persisted_farm
          field = begin
            farm.fields.find(field_id)
          rescue ActiveRecord::RecordNotFound
            raise Domain::Shared::Exceptions::RecordNotFound, "Field not found"
          end
          Domain::Field::Dtos::AuthorizedFieldLoadedInFarmDto.new(
            field_entity: Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(field),
            persisted_field: field
          )
        end

        def create_for_user(user, farm_id, attrs)
          farm = find_farm_model!(farm_id)
          unless Domain::Shared::Policies::FarmPolicy.edit_allowed?(user, is_reference: farm.is_reference, user_id: farm.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          field = FieldPolicy.build_for_create(user, farm, attrs.to_h.symbolize_keys)
          raise Domain::Shared::Exceptions::RecordInvalid, field.errors.full_messages.join(", ") unless field.save

          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(field)
        end

        def update_for_user(user, id, attrs)
          field = find_field_model!(id)
          unless field_edit_allowed?(user, field)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          normalized = attrs.to_h.symbolize_keys.slice(:name, :area, :daily_fixed_cost, :region)
          raise Domain::Shared::Exceptions::RecordInvalid, field.errors.full_messages.join(", ") unless field.update(normalized)

          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(field.reload)
        end

        def soft_destroy_with_undo(user:, field_id:, auto_hide_after: 5000, translator:)
          field = find_field_model!(field_id)
          unless field_edit_allowed?(user, field)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          name = field.display_name
          toast_message = translator.t("fields.undo.toast", name: name)
          undo_gw = @deletion_undo_gateway
          event = undo_gw.schedule(
            resource_type: field.class.name,
            resource_id: field.id,
            actor_id: user.id,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after,
            metadata: { farm_id: field.farm_id }
          )
          { success: true, undo_entity: event, resource_name: name }
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue Domain::Shared::Exceptions::AssociationInUse
          raise
        rescue Domain::Shared::Exceptions::RecordNotFound
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(e.message) }
        end

        def build_blank_field_for_master_form!(persisted_farm:)
          persisted_farm.fields.build
        end

        private

        def farm_entity_and_field_entities_for_farm_list!(farm_id, user_id)
          user = find_user!(user_id)
          farm_entity = @farm_gateway.find_authorized_for_edit(user, farm_id)
          farm = ::Farm.find(farm_id)
          scope = FieldPolicy.scope_for_farm(user, farm)
          fields = scope.map { |record| Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(record) }
          [ farm_entity, fields ]
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied
          raise
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Farm not found"
        end

        def find_user!(user_id)
          ::User.find(user_id)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "User not found"
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

        def field_view_allowed?(user, field)
          farm = field.farm
          Domain::Shared::Policies::FarmPolicy.view_allowed?(user, is_reference: farm.is_reference, user_id: farm.user_id)
        end

        def field_edit_allowed?(user, field)
          farm = field.farm
          Domain::Shared::Policies::FarmPolicy.edit_allowed?(user, is_reference: farm.is_reference, user_id: farm.user_id)
        end
      end
    end
  end
end
