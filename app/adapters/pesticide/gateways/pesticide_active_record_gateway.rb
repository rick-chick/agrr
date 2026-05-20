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

        def list_index_for_filter(filter)
          index_relation_for_filter(filter).map { |record| Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(record) }
        end

        def find_authorized_for_view(user, id, access_filter:)
          Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(find_authorized_model_for_view(user, id, access_filter: access_filter))
        end

        def authorized_pesticide_detail_output(user, id, access_filter:)
          pesticide = ::Pesticide.includes(:crop, :pest, :pesticide_usage_constraint, :pesticide_application_detail).find(id)
          unless access_filter.view_allows?(is_reference: pesticide.is_reference, record_user_id: pesticide.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          Adapters::Pesticide::Mappers::PesticideMapper.detail_output_dto_from_record(pesticide)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Pesticide not found"
        end

        def find_authorized_for_edit(user, id, access_filter:)
          Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(find_authorized_model_for_edit(user, id, access_filter: access_filter))
        end

        def find_authorized_pesticide_loaded_bundle!(user, id, for_edit:, access_filter:)
          pesticide = if for_edit
                        find_authorized_model_for_edit(user, id, access_filter: access_filter)
                      else
                        find_authorized_model_for_view(user, id, access_filter: access_filter)
                      end
          Domain::Pesticide::Dtos::AuthorizedPesticideLoaded.new(
            pesticide_entity: Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(pesticide),
            master_form_snapshot: Adapters::Pesticide::Mappers::PesticideMasterFormSnapshotMapper.from_record(pesticide)
          )
        end

        def create_for_user(user, attrs)
          pesticide = ::Pesticide.new(attrs.to_h.symbolize_keys)
          raise Domain::Shared::Exceptions::RecordInvalid, pesticide.errors.full_messages.join(", ") unless pesticide.save

          Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(pesticide)
        end

        def update_for_user(user, id, attrs, access_filter:)
          pesticide = find_pesticide_model!(id)
          unless access_filter.edit_allows?(is_reference: pesticide.is_reference, record_user_id: pesticide.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          raise Domain::Shared::Exceptions::RecordInvalid, pesticide.errors.full_messages.join(", ") unless pesticide.update(attrs.to_h.symbolize_keys)

          Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(pesticide.reload)
        end

        def list_for_crop_with_user(crop_id:, user:)
          ::Pesticide.where(crop_id: crop_id, id: selectable_scope(user).select(:id)).recent.map do |record|
            Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(record)
          end
        end

        def build_blank_pesticide_for_master_form
          p = ::Pesticide.new
          p.build_pesticide_usage_constraint
          p.build_pesticide_application_detail
          p
        end

        def build_pesticide_for_create_failure_master_form(attributes_hash)
          ::Pesticide.new(attributes_hash || {})
        end

        def ensure_nested_associations_for_pesticide_master_form!(pesticide)
          pesticide.build_pesticide_usage_constraint unless pesticide.pesticide_usage_constraint
          pesticide.build_pesticide_application_detail unless pesticide.pesticide_application_detail
          pesticide
        end

        def assign_pesticide_attributes_for_master_form!(pesticide, attributes_hash)
          pesticide.assign_attributes(attributes_hash || {})
          pesticide
        end

        # マスタCRUD update 失敗時にパラメータをマージして {Forms::PesticideMasterForm} を返す
        def merge_edit_pesticide_params_for_master_form!(user:, pesticide_id:, attributes:, access_filter:)
          pesticide = find_authorized_model_for_edit(user, pesticide_id.to_i, access_filter: access_filter)
          ensure_nested_associations_for_pesticide_master_form!(pesticide)
          pesticide.assign_attributes(attributes || {})
          pesticide.valid?
          snapshot = Adapters::Pesticide::Mappers::PesticideMasterFormSnapshotMapper.from_record(pesticide, error_messages: pesticide.errors.full_messages)
          Forms::PesticideMasterForm.from_snapshot(snapshot)
        rescue Domain::Shared::Exceptions::RecordNotFound
          raise
        end

        # マスタCRUD create 失敗時に属性付き新規 Pesticide を {Forms::PesticideMasterForm} として返す
        def build_new_pesticide_with_attributes_for_master_form(attributes:)
          pesticide = ::Pesticide.new(attributes || {})
          ensure_nested_associations_for_pesticide_master_form!(pesticide)
          pesticide.valid?
          snapshot = Adapters::Pesticide::Mappers::PesticideMasterFormSnapshotMapper.from_record(pesticide, error_messages: pesticide.errors.full_messages)
          Forms::PesticideMasterForm.from_snapshot(snapshot)
        end

        def accessible_crops_scope_for_pesticide_master_form(user:)
          Domain::Shared::PesticideAssociationAccess.accessible_crops_scope(user)
        end

        def accessible_pests_scope_for_pesticide_master_form(user:)
          Domain::Shared::PesticideAssociationAccess.accessible_pests_scope(user)
        end

        def soft_destroy_with_undo(user:, pesticide_id:, auto_hide_after: 5000, translator:, access_filter:)
          pesticide = find_pesticide_model!(pesticide_id)
          unless access_filter.edit_allows?(is_reference: pesticide.is_reference, record_user_id: pesticide.user_id)
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
          { success: false, error_dto: Domain::Shared::Dtos::Error.new(e.message) }
        end

        private

        def index_relation_for_filter(filter)
          case filter.mode
          when :reference_or_owned
            ::Pesticide.where("is_reference = ? OR user_id = ?", true, filter.user_id)
          when :owned_non_reference
            ::Pesticide.where(user_id: filter.user_id, is_reference: false)
          else
            raise ArgumentError, "unknown ReferenceIndexListFilter mode: #{filter.mode.inspect}"
          end
        end

        def selectable_scope(user)
          ::Pesticide.where("is_reference = ? OR user_id = ?", true, user.id)
        end

        def find_authorized_model_for_view(user, id, access_filter:)
          pesticide = find_pesticide_model!(id)
          unless access_filter.view_allows?(is_reference: pesticide.is_reference, record_user_id: pesticide.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          pesticide
        end

        def find_authorized_model_for_edit(user, id, access_filter:)
          pesticide = find_pesticide_model!(id)
          unless access_filter.edit_allows?(is_reference: pesticide.is_reference, record_user_id: pesticide.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          pesticide
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
