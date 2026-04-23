# frozen_string_literal: true

module Adapters
  module Pest
    module Gateways
      class PestMemoryGateway < Domain::Pest::Gateways::PestGateway
        def list(query = nil)
          if query.is_a?(Domain::Shared::Dtos::QueryDto)
            scope = build_scope_from_query(query)
          else
            scope = query || ::Pest.all
          end
          scope.map { |record| Domain::Pest::Entities::PestEntity.from_model(record) }
        end

        def visible_records(user)
          if user.admin?
            ::Pest.where("is_reference = ? OR user_id = ?", true, user.id)
          else
            ::Pest.where(user_id: user.id, is_reference: false)
          end
        end

        def selectable_records(user)
          ::Pest.where("is_reference = ? OR user_id = ?", true, user.id)
        end

        def find_authorized_for_view(user, id)
          pest = find_pest_model!(id)
          unless Domain::Shared::Policies::PestPolicy.view_allowed?(user, is_reference: pest.is_reference, user_id: pest.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          pest
        end

        def find_authorized_for_edit(user, id)
          pest = find_pest_model!(id)
          unless Domain::Shared::Policies::PestPolicy.edit_allowed?(user, is_reference: pest.is_reference, user_id: pest.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          pest
        end

        def find_model(id)
          find_pest_model!(id)
        end

        def create_for_user(user, attrs)
          h = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_create(user, attrs)
          pest = ::Pest.new(h)
          raise StandardError, pest.errors.full_messages.join(", ") unless pest.save

          pest
        end

        def update_for_user(user, id, attrs)
          pest = find_pest_model!(id)
          unless Domain::Shared::Policies::PestPolicy.edit_allowed?(user, is_reference: pest.is_reference, user_id: pest.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          normalized = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_update(
            user,
            pest.attributes.symbolize_keys,
            attrs
          )
          success = pest.update(normalized)
          if success
            success = pest.pest_temperature_profile&.valid? != false &&
                     pest.pest_thermal_requirement&.valid? != false &&
                     pest.pest_control_methods.all? { |method| method.valid? }
          end
          raise StandardError, pest.errors.full_messages.join(", ") unless success

          pest.reload
        end

        def find_by_id(pest_id)
          pest = ::Pest.find(pest_id)
          Domain::Pest::Entities::PestEntity.from_model(pest)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, "Pest not found"
        end

        def create(create_input_dto)
          pest = ::Pest.new(
            name: create_input_dto.name,
            name_scientific: create_input_dto.name_scientific,
            family: create_input_dto.family,
            order: create_input_dto.order,
            description: create_input_dto.description,
            occurrence_season: create_input_dto.occurrence_season,
            region: create_input_dto.region
          )
          raise StandardError, pest.errors.full_messages.join(", ") unless pest.save

          Domain::Pest::Entities::PestEntity.from_model(pest)
        end

        def update(pest_id, update_input_dto)
          pest = ::Pest.find(pest_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:name_scientific] = update_input_dto.name_scientific if !update_input_dto.name_scientific.nil?
          attrs[:family] = update_input_dto.family if !update_input_dto.family.nil?
          attrs[:order] = update_input_dto.order if !update_input_dto.order.nil?
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:occurrence_season] = update_input_dto.occurrence_season if !update_input_dto.occurrence_season.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?

          pest.update(attrs)
          raise StandardError, pest.errors.full_messages.join(", ") if pest.errors.any?

          Domain::Pest::Entities::PestEntity.from_model(pest.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, "Pest not found"
        end

        private

        def find_pest_model!(id)
          ::Pest.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def build_scope_from_query(query)
          return ::Pest.all unless query.present?

          ::Pest.all
        end
      end
    end
  end
end
