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
          ::DeletionUndo::Manager.schedule(
            record: fertilize,
            actor: Adapters::Shared::UserActorResolver.user_for_deleted_by(fertilize.user),
            toast_message: @translator.t("fertilizes.undo.toast", name: fertilize.name)
          )
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError, Domain::Shared::Exceptions::AssociationInUse
          raise Domain::Shared::Exceptions::AssociationInUse, @translator.t("fertilizes.flash.cannot_delete_in_use")
        rescue ::DeletionUndo::Error
          raise
        end

        def list_index_for_filter(filter)
          index_relation_for_filter(filter)
            .where.not(name: [ nil, "" ])
            .map { |record| Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(record) }
        end

        def find_authorized_model_for_view(user, id)
          fertilize = find_fertilize_model!(id)
          unless Domain::Shared::Policies::FertilizePolicy.view_allowed?(user, is_reference: fertilize.is_reference, user_id: fertilize.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          fertilize
        end

        def find_authorized_model_for_edit(user, id)
          fertilize = find_fertilize_model!(id)
          unless Domain::Shared::Policies::FertilizePolicy.edit_allowed?(user, is_reference: fertilize.is_reference, user_id: fertilize.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          fertilize
        end

        def find_authorized_for_view(user, id)
          Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(find_authorized_model_for_view(user, id))
        end

        def find_authorized_for_edit(user, id)
          Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(find_authorized_model_for_edit(user, id))
        end

        def find_authorized_fertilize_loaded_bundle!(user, id, for_edit:)
          fertilize = if for_edit
                        find_authorized_model_for_edit(user, id)
                      else
                        find_authorized_model_for_view(user, id)
                      end
          Domain::Fertilize::Dtos::AuthorizedFertilizeLoadedDto.new(
            fertilize_entity: Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(fertilize),
            persisted_fertilize: fertilize
          )
        end

        def create_for_user(user, attrs)
          h = Domain::Shared::Policies::FertilizePolicy.normalize_attrs_for_create(user, attrs)
          fertilize = ::Fertilize.new(h)
          raise Domain::Shared::Exceptions::RecordInvalid, fertilize.errors.full_messages.join(", ") unless fertilize.save

          Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(fertilize)
        end

        def update_for_user(user, id, attrs)
          fertilize = find_fertilize_model!(id)
          unless Domain::Shared::Policies::FertilizePolicy.edit_allowed?(user, is_reference: fertilize.is_reference, user_id: fertilize.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          normalized = Domain::Shared::Policies::FertilizePolicy.normalize_attrs_for_update(
            user,
            fertilize.attributes.symbolize_keys,
            attrs
          )
          raise Domain::Shared::Exceptions::RecordInvalid, fertilize.errors.full_messages.join(", ") unless fertilize.update(normalized)

          Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(fertilize.reload)
        end

        def soft_destroy_with_undo(user:, fertilize_id:, auto_hide_after: 5000, translator:)
          fertilize = find_fertilize_model!(fertilize_id)
          unless Domain::Shared::Policies::FertilizePolicy.edit_allowed?(user, is_reference: fertilize.is_reference, user_id: fertilize.user_id)
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
          { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(e.message) }
        end

        def find_user_owned_non_reference_fertilize_record_by_name(user_id:, name:)
          return nil if name.blank?

          ::Fertilize.find_by(name: name, is_reference: false, user_id: user_id)
        end

        def build_blank_fertilize_for_master_form
          ::Fertilize.new
        end

        private

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

        def find_fertilize_model!(id)
          ::Fertilize.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
