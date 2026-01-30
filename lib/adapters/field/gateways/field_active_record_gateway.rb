# frozen_string_literal: true

module Adapters
  module Field
    module Gateways
      class FieldActiveRecordGateway < Domain::Field::Gateways::FieldGateway
        def list_by_farm(farm_id, user_id)
          user = find_user!(user_id)
          farm = Domain::Shared::Policies::FarmPolicy.find_owned!(::Farm, user, farm_id)
          scope = FieldPolicy.scope_for_farm(user, farm)
          scope.map { |record| Domain::Farm::Entities::FieldEntity.from_model(record) }
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied, ActiveRecord::RecordNotFound
          raise StandardError, 'Farm not found'
        end

        def find_by_id_and_user(field_id, user_id)
          user = User.find(user_id)
          record = FieldPolicy.find_owned!(user, field_id)
          Domain::Farm::Entities::FieldEntity.from_model(record)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied, ActiveRecord::RecordNotFound
          raise StandardError, 'Field not found'
        end

        def create(create_input_dto, farm_id, user_id)
          user = User.find(user_id)
          farm = Domain::Shared::Policies::FarmPolicy.find_owned!(::Farm, user, farm_id)
          attrs = {
            name: create_input_dto.name,
            area: create_input_dto.area,
            daily_fixed_cost: create_input_dto.daily_fixed_cost,
            region: create_input_dto.region
          }
          field = FieldPolicy.build_for_create(user, farm, attrs)
          raise StandardError, field.errors.full_messages.join(', ') unless field.save

          Domain::Farm::Entities::FieldEntity.from_model(field)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied, ActiveRecord::RecordNotFound
          raise StandardError, 'Farm not found'
        end

        def update(field_id, update_input_dto, user_id)
          user = User.find(user_id)
          field = FieldPolicy.find_owned!(user, field_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:area] = update_input_dto.area if !update_input_dto.area.nil?
          attrs[:daily_fixed_cost] = update_input_dto.daily_fixed_cost if !update_input_dto.daily_fixed_cost.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?
          raise StandardError, field.errors.full_messages.join(', ') unless field.update(attrs)

          Domain::Farm::Entities::FieldEntity.from_model(field.reload)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied, ActiveRecord::RecordNotFound
          raise StandardError, 'Field not found'
        end

        def destroy(field_id, user_id)
          user = User.find(user_id)
          field = FieldPolicy.find_owned!(user, field_id)
          DeletionUndo::Manager.schedule(
            record: field,
            actor: user,
            toast_message: I18n.t('fields.undo.toast', name: field.display_name),
            metadata: {
              farm_id: field.farm_id
            }
          )
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied, ActiveRecord::RecordNotFound
          raise StandardError, 'Field not found'
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise StandardError, I18n.t('fields.flash.cannot_delete_in_use')
        rescue DeletionUndo::Error => e
          raise StandardError, e.message
        end

        private

        def find_user!(user_id)
          User.find(user_id)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'User not found'
        end
      end
    end
  end
end
