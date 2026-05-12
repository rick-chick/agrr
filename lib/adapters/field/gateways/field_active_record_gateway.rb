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

        def authorized_farm_fields_list(farm_id, farm_access_filter:)
          farm_entity, fields = farm_entity_and_field_entities_for_farm_list!(farm_id, farm_access_filter)
          Domain::Field::Results::FarmFieldsList.new(farm: farm_entity, fields: fields)
        end

        def field_with_farm_for_user(field_id, farm_access_filter:)
          user = farm_access_filter.user
          field_entity = find_by_id_and_user(field_id, user.id)
          farm_entity = @farm_gateway.find_authorized_for_edit(user, field_entity.farm_id, access_filter: farm_access_filter)
          Domain::Field::Results::FieldWithFarm.new(farm: farm_entity, field: field_entity)
        end

        def find_by_id_and_user(field_id, user_id)
          user = ::User.find(user_id)
          record = find_field_model!(field_id)
          assert_field_owned_by_user!(user, record)
          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(record)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied, ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Field not found"
        end

        def create(create_input_dto, farm_id, farm_access_filter:)
          user = farm_access_filter.user
          @farm_gateway.find_authorized_for_edit(user, farm_id, access_filter: farm_access_filter)
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
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied, ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Farm not found"
        end

        def update(field_id, update_input_dto, farm_access_filter:)
          user = farm_access_filter.user
          field = find_field_model!(field_id)
          assert_field_owned_by_user!(user, field)
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

        def destroy(field_id, farm_access_filter:)
          user = farm_access_filter.user
          field = find_field_model!(field_id)
          assert_field_owned_by_user!(user, field)
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

        def find_authorized_for_view(user, id, farm_access_filter:)
          field = find_field_model!(id)
          unless field_view_allowed?(farm_access_filter, field)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(field)
        end

        def find_authorized_for_edit(user, id, farm_access_filter:)
          field = find_field_model!(id)
          unless field_edit_allowed?(farm_access_filter, field)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(field)
        end

        def find_authorized_field_loaded_in_farm!(user, farm_id, field_id, farm_access_filter:)
          @farm_gateway.find_authorized_farm_loaded_bundle!(user, farm_id, for_edit: true, access_filter: farm_access_filter)
          field = begin
            ::Field.where(farm_id: farm_id).find(field_id)
          rescue ActiveRecord::RecordNotFound
            raise Domain::Shared::Exceptions::RecordNotFound, "Field not found"
          end
          Domain::Field::Dtos::AuthorizedFieldLoadedInFarmDto.new(
            field_entity: Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(field),
            master_form_snapshot: Adapters::Farm::Mappers::FieldMasterFormSnapshotMapper.from_record(field)
          )
        end

        def create_for_user(user, farm_id, attrs, farm_access_filter:)
          farm = find_farm_model!(farm_id)
          unless farm_access_filter.edit_allows?(is_reference: farm.is_reference, record_user_id: farm.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          field = build_field_for_create(user, farm, attrs.to_h.symbolize_keys)
          raise Domain::Shared::Exceptions::RecordInvalid, field.errors.full_messages.join(", ") unless field.save

          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(field)
        end

        def update_for_user(user, id, attrs, farm_access_filter:)
          field = find_field_model!(id)
          unless field_edit_allowed?(farm_access_filter, field)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          normalized = attrs.to_h.symbolize_keys.slice(:name, :area, :daily_fixed_cost, :region)
          raise Domain::Shared::Exceptions::RecordInvalid, field.errors.full_messages.join(", ") unless field.update(normalized)

          Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(field.reload)
        end

        def soft_destroy_with_undo(user:, field_id:, auto_hide_after: 5000, translator:, farm_access_filter:)
          field = find_field_model!(field_id)
          unless field_edit_allowed?(farm_access_filter, field)
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

        def build_blank_field_for_master_form!(farm_id:, farm_access_filter:)
          farm = find_farm_model!(farm_id)
          unless farm_access_filter.edit_allows?(is_reference: farm.is_reference, record_user_id: farm.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          Adapters::Farm::Mappers::FieldMasterFormSnapshotMapper.from_record(farm.fields.build)
        end

        private

        def farm_entity_and_field_entities_for_farm_list!(farm_id, farm_access_filter)
          user = farm_access_filter.user
          farm_entity = @farm_gateway.find_authorized_for_edit(user, farm_id, access_filter: farm_access_filter)
          farm = ::Farm.find(farm_id)
          scope = fields_scope_for_authorized_farm!(user, farm)
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

        # Domain::Field::Policies::FieldAccess と同一条件（Adapter は FieldAccess を参照しない）
        def assert_field_owned_by_user!(user, field)
          allowed = user.admin? || field.farm.user_id == user.id
          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed

          field
        end

        def fields_scope_for_authorized_farm!(user, farm)
          unless farm.user_id == user.id || user.admin?
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          farm.fields
        end

        def build_field_for_create(user, farm, attrs)
          attributes = attrs.to_h.symbolize_keys
          attributes[:user_id] ||= user.id
          attributes[:farm_id] = farm.id
          ::Field.new(attributes)
        end

        def field_view_allowed?(farm_access_filter, field)
          farm = field.farm
          farm_access_filter.view_allows?(is_reference: farm.is_reference, record_user_id: farm.user_id)
        end

        def field_edit_allowed?(farm_access_filter, field)
          farm = field.farm
          farm_access_filter.edit_allows?(is_reference: farm.is_reference, record_user_id: farm.user_id)
        end
      end
    end
  end
end
