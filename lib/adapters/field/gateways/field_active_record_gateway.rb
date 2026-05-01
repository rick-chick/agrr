# frozen_string_literal: true

module Adapters
  module Field
    module Gateways
      class FieldActiveRecordGateway < Domain::Field::Gateways::FieldGateway
        attr_accessor :translator

        def initialize
          @translator = Adapters::Translators::RailsTranslator.new
        end

        def list_by_farm(farm_id, user_id)
          user = find_user!(user_id)
          Domain::Farm::Gateways::FarmGateway.default.find_authorized_for_edit(user, farm_id)
          farm = ::Farm.find(farm_id)
          scope = FieldPolicy.scope_for_farm(user, farm)
          scope.map { |record| Adapters::Farm::Mappers::FarmMapper.field_entity_from_record(record) }
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied, ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Farm not found"
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
          Domain::Farm::Gateways::FarmGateway.default.find_authorized_for_edit(user, farm_id)
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

        def find_model(id)
          ::Field.find(id)
        end

        def destroy(field_id, user_id)
          user = ::User.find(user_id)
          field = FieldPolicy.find_owned!(user, field_id)
          DeletionUndo::Manager.schedule(
            record: field,
            actor: Adapters::Shared::UserActorResolver.user_for_deleted_by(user),
            toast_message: @translator.t("fields.undo.toast", name: field.display_name),
            metadata: {
              farm_id: field.farm_id
            }
          )
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied, ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Field not found"
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise Domain::Shared::Exceptions::AssociationInUse, @translator.t("fields.flash.cannot_delete_in_use")
        rescue DeletionUndo::Error => e
          raise StandardError, e.message
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

        def soft_destroy_with_undo(user:, field_id:, auto_hide_after: 5000, translator: nil)
          translator ||= @translator
          translator ||= Adapters::Translators::RailsTranslator.new
          field = find_field_model!(field_id)
          unless field_edit_allowed?(user, field)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          name = field.display_name
          toast_message = translator.t("fields.undo.toast", name: name)
          undo_gw = Domain::DeletionUndo::Gateways::DeletionUndoGateway.default
          event = undo_gw.schedule(
            record: field,
            actor: Adapters::Shared::UserActorResolver.user_for_deleted_by(user),
            toast_message: toast_message,
            auto_hide_after: auto_hide_after,
            metadata: { farm_id: field.farm_id }
          )
          { success: true, undo_entity: event, resource_name: name }
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue Domain::Shared::Exceptions::AssociationInUse
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(e.message) }
        end

        private

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
