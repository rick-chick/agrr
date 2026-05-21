# frozen_string_literal: true

module Adapters
  module Fertilize
    module Gateways
      class FertilizeActiveRecordGateway < Domain::Fertilize::Gateways::FertilizeGateway
        attr_accessor :translator

        def initialize(deletion_undo_gateway:, translator:)
          @deletion_undo_gateway = deletion_undo_gateway
          @translator = translator
        end

        def find_by_id(fertilize_id)
          fertilize = ::Fertilize.find(fertilize_id)
          Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(fertilize)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def create(create_input_dto)
          fertilize = ::Fertilize.new(
            name: create_input_dto.name,
            n: create_input_dto.n,
            p: create_input_dto.p,
            k: create_input_dto.k,
            description: create_input_dto.description,
            package_size: create_input_dto.package_size,
            region: create_input_dto.region,
            is_reference: create_input_dto.is_reference || false,
            user_id: create_input_dto.user_id
          )
          raise Domain::Shared::Exceptions::RecordInvalid, fertilize.errors.full_messages.join(", ") unless fertilize.save

          Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(fertilize)
        end

        def update(fertilize_id, update_input_dto)
          fertilize = ::Fertilize.find(fertilize_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:n] = update_input_dto.n if !update_input_dto.n.nil?
          attrs[:p] = update_input_dto.p if !update_input_dto.p.nil?
          attrs[:k] = update_input_dto.k if !update_input_dto.k.nil?
          attrs[:description] = update_input_dto.description if update_input_dto.description.present?
          attrs[:package_size] = update_input_dto.package_size if update_input_dto.package_size.present?
          attrs[:region] = update_input_dto.region if update_input_dto.region.present?
          raise Domain::Shared::Exceptions::RecordInvalid, fertilize.errors.full_messages.join(", ") unless fertilize.update(attrs)

          Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(fertilize.reload)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def destroy(fertilize_id)
          fertilize = ::Fertilize.find(fertilize_id)
          ::Adapters::DeletionUndo::Manager.schedule(
            record: fertilize,
            actor: Adapters::Shared::UserActorResolver.user_for_deleted_by(fertilize.user),
            toast_message: @translator.t("fertilizes.undo.toast", name: fertilize.name)
          )
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError, Domain::Shared::Exceptions::AssociationInUse
          raise Domain::Shared::Exceptions::AssociationInUse, @translator.t("fertilizes.flash.cannot_delete_in_use")
        rescue ::Domain::DeletionUndo::Exceptions::DeletionUndoError
          raise
        end

        def list_index_for_filter(filter)
          index_relation_for_filter(filter)
            .where.not(name: [ nil, "" ])
            .map { |record| Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(record) }
        end

        def find_authorized_for_view(user, id, access_filter:)
          Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(find_authorized_model_for_view(user, id, access_filter: access_filter))
        end

        def find_authorized_for_edit(user, id, access_filter:)
          Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(find_authorized_model_for_edit(user, id, access_filter: access_filter))
        end

        def find_authorized_fertilize_loaded_bundle!(user, id, for_edit:, access_filter:)
          fertilize = if for_edit
                        find_authorized_model_for_edit(user, id, access_filter: access_filter)
                      else
                        find_authorized_model_for_view(user, id, access_filter: access_filter)
                      end
          Domain::Fertilize::Dtos::AuthorizedFertilizeLoaded.new(
            fertilize_entity: Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(fertilize),
            master_form_snapshot: Adapters::Fertilize::Mappers::FertilizeMasterFormSnapshotMapper.from_record(fertilize)
          )
        end

        def create_for_user(user, attrs)
          fertilize = ::Fertilize.new(attrs.to_h.symbolize_keys)
          raise Domain::Shared::Exceptions::RecordInvalid, fertilize.errors.full_messages.join(", ") unless fertilize.save

          Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(fertilize)
        end

        def update_for_user(user, id, attrs, access_filter:)
          fertilize = find_fertilize_model!(id)
          unless access_filter.edit_allows?(is_reference: fertilize.is_reference, record_user_id: fertilize.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          raise Domain::Shared::Exceptions::RecordInvalid, fertilize.errors.full_messages.join(", ") unless fertilize.update(attrs.to_h.symbolize_keys)

          Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(fertilize.reload)
        end

        def soft_delete_with_undo(user:, fertilize_id:, auto_hide_after: 5000, translator:, access_filter:)
          fertilize = find_fertilize_model!(fertilize_id)
          unless access_filter.edit_allows?(is_reference: fertilize.is_reference, record_user_id: fertilize.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          name = fertilize.name
          toast_message = translator.t("fertilizes.undo.toast", name: name)
          undo_gw = @deletion_undo_gateway
          event = undo_gw.schedule(
            resource_type: fertilize.class.name,
            resource_id: fertilize.id,
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

        def find_user_owned_non_reference_fertilize_record_by_name(user_id:, name:)
          return nil if name.blank?

          ::Fertilize.find_by(name: name, is_reference: false, user_id: user_id)
        end

        def build_blank_fertilize_for_master_form
          ::Fertilize.new
        end

        def build_after_create_failure_fertilize_for_master_form!(user:, attributes:)
          sym = attributes.respond_to?(:symbolize_keys) ? attributes.symbolize_keys : attributes.to_h.symbolize_keys
          fertilize = ::Fertilize.new(
            user_id: user.id,
            name: sym[:name],
            n: sym[:n],
            p: sym[:p],
            k: sym[:k],
            description: sym[:description],
            package_size: sym[:package_size],
            region: sym[:region],
            is_reference: sym[:is_reference]
          )
          fertilize.valid?
          fertilize
        end

        private

        def find_authorized_model_for_edit(user, id, access_filter:)
          fertilize = find_fertilize_model!(id)
          unless access_filter.edit_allows?(is_reference: fertilize.is_reference, record_user_id: fertilize.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          fertilize
        end

        def index_relation_for_filter(filter)
          case filter.mode
          when :reference_or_owned
            ::Fertilize.where("is_reference = ? OR user_id = ?", true, filter.user_id)
          when :owned_non_reference
            ::Fertilize.where(user_id: filter.user_id, is_reference: false)
          else
            raise ArgumentError, "unknown ReferenceIndexListFilter mode: #{filter.mode.inspect}"
          end
        end

        def find_authorized_model_for_view(user, id, access_filter:)
          fertilize = find_fertilize_model!(id)
          unless access_filter.view_allows?(is_reference: fertilize.is_reference, record_user_id: fertilize.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          fertilize
        end

        def find_fertilize_model!(id)
          ::Fertilize.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
