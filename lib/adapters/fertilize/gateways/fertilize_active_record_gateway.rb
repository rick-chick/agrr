# frozen_string_literal: true

module Adapters
  module Fertilize
    module Gateways
      class FertilizeActiveRecordGateway < Domain::Fertilize::Gateways::FertilizeGateway
        attr_accessor :translator

        def initialize(deletion_undo_gateway:, translator: nil)
          @deletion_undo_gateway = deletion_undo_gateway
          @translator = translator || Adapters::Translators::RailsTranslator.new
        end

        def list
          ::Fertilize.all.map { |record| Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(record) }
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
          DeletionUndo::Manager.schedule(
            record: fertilize,
            actor: Adapters::Shared::UserActorResolver.user_for_deleted_by(fertilize.user),
            toast_message: @translator.t("fertilizes.undo.toast", name: fertilize.name)
          )
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise Domain::Shared::Exceptions::AssociationInUse, @translator.t("fertilizes.flash.cannot_delete_in_use")
        rescue DeletionUndo::Error => e
          raise StandardError, e.message
        end

        def list_index_for_user(user)
          fertilize_visible_scope(user)
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

        def find_model(id)
          find_fertilize_model!(id)
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

        def soft_destroy_with_undo(user:, fertilize_id:, auto_hide_after: 5000, translator: nil)
          translator ||= @translator
          translator ||= Adapters::Translators::RailsTranslator.new
          fertilize = find_fertilize_model!(fertilize_id)
          unless Domain::Shared::Policies::FertilizePolicy.edit_allowed?(user, is_reference: fertilize.is_reference, user_id: fertilize.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          name = fertilize.name
          toast_message = translator.t("fertilizes.undo.toast", name: name)
          undo_gw = @deletion_undo_gateway
          event = undo_gw.schedule(
            record: fertilize,
            actor: user,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after
          )
          { success: true, undo_entity: event, resource_name: name }
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(e.message) }
        end

        private

        def fertilize_visible_scope(user)
          if user.admin?
            ::Fertilize.where("is_reference = ? OR user_id = ?", true, user.id)
          else
            ::Fertilize.where(user_id: user.id, is_reference: false)
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
