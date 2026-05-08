# frozen_string_literal: true

module Adapters
  module Pesticide
    module Gateways
      class PesticideActiveRecordGateway < Domain::Pesticide::Gateways::PesticideGateway
        attr_accessor :translator

        def initialize(deletion_undo_gateway:, translator:)
          @deletion_undo_gateway = deletion_undo_gateway
          @translator = translator
        end

        def list
          ::Pesticide.all.map { |record| Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(record) }
        end

        def find_by_id(pesticide_id)
          pesticide = ::Pesticide.find(pesticide_id)
          Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(pesticide)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Pesticide not found"
        end

        def create(create_input_dto)
          pesticide = ::Pesticide.new(
            name: create_input_dto.name,
            active_ingredient: create_input_dto.active_ingredient,
            description: create_input_dto.description,
            crop_id: create_input_dto.crop_id,
            pest_id: create_input_dto.pest_id,
            region: create_input_dto.region
          )
          raise Domain::Shared::Exceptions::RecordInvalid, pesticide.errors.full_messages.join(", ") unless pesticide.save

          Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(pesticide)
        end

        def update(pesticide_id, update_input_dto)
          pesticide = ::Pesticide.find(pesticide_id)
          attrs = {}
          attrs[:name] = update_input_dto.name unless update_input_dto.name.nil?
          attrs[:active_ingredient] = update_input_dto.active_ingredient if !update_input_dto.active_ingredient.nil?
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:crop_id] = update_input_dto.crop_id if !update_input_dto.crop_id.nil?
          attrs[:pest_id] = update_input_dto.pest_id if !update_input_dto.pest_id.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?

          pesticide.update(attrs)
          raise Domain::Shared::Exceptions::RecordInvalid, pesticide.errors.full_messages.join(", ") if pesticide.errors.any?

          Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(pesticide.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Pesticide not found"
        end

        def destroy(pesticide_id)
          pesticide = ::Pesticide.find(pesticide_id)
          # DeletionUndo scheduling is handled in the interactor layer
          pesticide.destroy!
          true
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Pesticide not found"
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise Domain::Shared::Exceptions::AssociationInUse, @translator.t("pesticides.flash.cannot_delete_in_use")
        end

        def list_index_for_user(user)
          visible_scope(user).map { |record| Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(record) }
        end

        def find_authorized_model_for_view(user, id)
          pesticide = find_pesticide_model!(id)
          unless Domain::Shared::Policies::PesticidePolicy.view_allowed?(user, is_reference: pesticide.is_reference, user_id: pesticide.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          pesticide
        end

        def find_authorized_model_for_edit(user, id)
          pesticide = find_pesticide_model!(id)
          unless Domain::Shared::Policies::PesticidePolicy.edit_allowed?(user, is_reference: pesticide.is_reference, user_id: pesticide.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          pesticide
        end

        def find_authorized_for_view(user, id)
          Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(find_authorized_model_for_view(user, id))
        end

        def authorized_pesticide_detail_output(user, id)
          pesticide = ::Pesticide.includes(:crop, :pest, :pesticide_usage_constraint, :pesticide_application_detail).find(id)
          unless Domain::Shared::Policies::PesticidePolicy.view_allowed?(user, is_reference: pesticide.is_reference, user_id: pesticide.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          Adapters::Pesticide::Mappers::PesticideMapper.detail_output_dto_from_record(pesticide)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Pesticide not found"
        end

        def find_authorized_for_edit(user, id)
          Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(find_authorized_model_for_edit(user, id))
        end

        def find_authorized_pesticide_loaded_bundle!(user, id, for_edit:)
          pesticide = if for_edit
                        find_authorized_model_for_edit(user, id)
                      else
                        find_authorized_model_for_view(user, id)
                      end
          Domain::Pesticide::Dtos::AuthorizedPesticideLoadedDto.new(
            pesticide_entity: Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(pesticide),
            persisted_pesticide: pesticide
          )
        end

        def create_for_user(user, attrs)
          h = Domain::Shared::Policies::PesticidePolicy.normalize_attrs_for_create(user, attrs)
          pesticide = ::Pesticide.new(h)
          raise Domain::Shared::Exceptions::RecordInvalid, pesticide.errors.full_messages.join(", ") unless pesticide.save

          Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(pesticide)
        end

        def update_for_user(user, id, attrs)
          pesticide = find_pesticide_model!(id)
          unless Domain::Shared::Policies::PesticidePolicy.edit_allowed?(user, is_reference: pesticide.is_reference, user_id: pesticide.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          normalized = Domain::Shared::Policies::PesticidePolicy.normalize_attrs_for_update(
            user,
            pesticide.attributes.symbolize_keys,
            attrs
          )
          raise Domain::Shared::Exceptions::RecordInvalid, pesticide.errors.full_messages.join(", ") unless pesticide.update(normalized)

          Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(pesticide.reload)
        end

        def list_for_crop_with_user(crop_id:, user:)
          ::Pesticide.where(crop_id: crop_id, id: selectable_scope(user).select(:id)).recent.map do |record|
            Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(record)
          end
        end

        def build_blank_pesticide_for_html_form
          p = ::Pesticide.new
          p.build_pesticide_usage_constraint
          p.build_pesticide_application_detail
          p
        end

        def build_pesticide_for_create_failure_html_form(attributes_hash)
          ::Pesticide.new(attributes_hash || {})
        end

        def ensure_nested_associations_for_pesticide_html_form!(pesticide)
          pesticide.build_pesticide_usage_constraint unless pesticide.pesticide_usage_constraint
          pesticide.build_pesticide_application_detail unless pesticide.pesticide_application_detail
          pesticide
        end

        def assign_pesticide_attributes_for_html_form!(pesticide, attributes_hash)
          pesticide.assign_attributes(attributes_hash || {})
          pesticide
        end

        def accessible_crops_scope_for_pesticide_html_form(user:)
          PesticideAssociationPolicy.accessible_crops_scope(user)
        end

        def accessible_pests_scope_for_pesticide_html_form(user:)
          PesticideAssociationPolicy.accessible_pests_scope(user)
        end

        def soft_destroy_with_undo(user:, pesticide_id:, auto_hide_after: 5000, translator:)
          pesticide = find_pesticide_model!(pesticide_id)
          unless Domain::Shared::Policies::PesticidePolicy.edit_allowed?(user, is_reference: pesticide.is_reference, user_id: pesticide.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          name = pesticide.name
          toast_message = translator.t("pesticides.undo.toast", name: name)
          undo_gw = @deletion_undo_gateway
          event = undo_gw.schedule(
            resource_type: pesticide.class.name,
            resource_id: pesticide.id,
            actor_id: user.id,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after
          )
          { success: true, undo_entity: event, resource_name: name }
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue Domain::Shared::Exceptions::RecordNotFound
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(e.message) }
        end

        private

        def visible_scope(user)
          if user.admin?
            ::Pesticide.where("is_reference = ? OR user_id = ?", true, user.id)
          else
            ::Pesticide.where(user_id: user.id, is_reference: false)
          end
        end

        def selectable_scope(user)
          ::Pesticide.where("is_reference = ? OR user_id = ?", true, user.id)
        end

        def find_pesticide_model!(id)
          ::Pesticide.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
