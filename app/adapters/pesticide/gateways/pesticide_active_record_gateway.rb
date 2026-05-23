# frozen_string_literal: true

module Adapters
  module Pesticide
    module Gateways
      class PesticideActiveRecordGateway < Domain::Pesticide::Gateways::PesticideGateway
        attr_accessor :translator

        def initialize(deletion_undo_gateway:, translator:, crop_gateway:, pest_gateway:)
          @deletion_undo_gateway = deletion_undo_gateway
          @translator = translator
          @crop_gateway = crop_gateway
          @pest_gateway = pest_gateway
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

        def list_index_for_filter(filter)
          index_relation_for_filter(filter).map { |record| Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(record) }
        end

        def authorized_pesticide_detail_output(id)
          pesticide = ::Pesticide.includes(:crop, :pest, :pesticide_usage_constraint, :pesticide_application_detail).find(id)
          Adapters::Pesticide::Mappers::PesticideMapper.detail_output_dto_from_record(pesticide)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Pesticide not found"
        end

        def find_pesticide_loaded_bundle!(id, for_edit:)
          pesticide = find_pesticide_model!(id)
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

        def update_for_user(_user, id, attrs)
          pesticide = find_pesticide_model!(id)
          raise Domain::Shared::Exceptions::RecordInvalid, pesticide.errors.full_messages.join(", ") unless pesticide.update(attrs.to_h.symbolize_keys)

          Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(pesticide.reload)
        end

        def list_for_crop_with_user(crop_id:, user:)
          ::Pesticide.where(crop_id: crop_id, id: selectable_scope(user).select(:id)).recent.map do |record|
            Adapters::Pesticide::Mappers::PesticideMapper.pesticide_entity_from_record(record)
          end
        end

        def ensure_nested_associations_for_pesticide_master_form!(pesticide)
          pesticide.build_pesticide_usage_constraint unless pesticide.pesticide_usage_constraint
          pesticide.build_pesticide_application_detail unless pesticide.pesticide_application_detail
          pesticide
        end

        def list_crop_pick_rows_for_pesticide_master_form(crop_list_filter:)
          crop_pick_entities(crop_list_filter).map do |crop|
            Domain::Pesticide::Dtos::PesticideMasterFormCropPickRow.new(id: crop.id, name: crop.name)
          end
        end

        def list_pest_pick_rows_for_pesticide_master_form(pest_list_filter:)
          pest_pick_entities(pest_list_filter).map do |pest|
            Domain::Pesticide::Dtos::PesticideMasterFormPestPickRow.new(id: pest.id, name: pest.name)
          end
        end

        def build_pesticide_master_form_snapshot_for_new(assign_attributes:)
          pesticide = ::Pesticide.new(assign_attributes || {})
          ensure_nested_associations_for_pesticide_master_form!(pesticide)
          pesticide.valid?
          Adapters::Pesticide::Mappers::PesticideMasterFormSnapshotMapper.from_record(
            pesticide,
            error_messages: pesticide.errors.full_messages
          )
        end

        def build_pesticide_master_form_snapshot_after_update_merge!(user:, pesticide_id:, assign_attributes:)
          pesticide = find_pesticide_model!(pesticide_id.to_i)
          ensure_nested_associations_for_pesticide_master_form!(pesticide)
          pesticide.assign_attributes(assign_attributes || {})
          pesticide.valid?
          Adapters::Pesticide::Mappers::PesticideMasterFormSnapshotMapper.from_record(
            pesticide,
            error_messages: pesticide.errors.full_messages
          )
        end

        def soft_delete_with_undo(user:, pesticide_id:, auto_hide_after: 5000, translator:)
          pesticide = find_pesticide_model!(pesticide_id)
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
        rescue Domain::Shared::Exceptions::RecordNotFound
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::Error.new(e.message) }
        end

        private

        def crop_pick_entities(crop_list_filter)
          @crop_gateway.list_index_for_filter(crop_list_filter).sort_by { |crop| crop.name.to_s }
        end

        def pest_pick_entities(pest_list_filter)
          @pest_gateway.list_index_for_filter(pest_list_filter).sort_by { |pest| pest.name.to_s }
        end

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

        def find_pesticide_model!(id)
          ::Pesticide.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
