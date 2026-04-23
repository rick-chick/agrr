# frozen_string_literal: true

module Adapters
  module Fertilize
    module Gateways
      class FertilizeActiveRecordGateway < Domain::Fertilize::Gateways::FertilizeGateway
        attr_accessor :translator
        def list
          ::Fertilize.all.map { |record| Domain::Fertilize::Entities::FertilizeEntity.from_model(record) }
        end

        def find_by_id(fertilize_id)
          fertilize = ::Fertilize.find(fertilize_id)
          Domain::Fertilize::Entities::FertilizeEntity.from_model(fertilize)
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
          raise StandardError, fertilize.errors.full_messages.join(", ") unless fertilize.save

          Domain::Fertilize::Entities::FertilizeEntity.from_model(fertilize)
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
          raise StandardError, fertilize.errors.full_messages.join(", ") unless fertilize.update(attrs)

          Domain::Fertilize::Entities::FertilizeEntity.from_model(fertilize.reload)
        end

        def destroy(fertilize_id)
          fertilize = ::Fertilize.find(fertilize_id)
          DeletionUndo::Manager.schedule(
            record: fertilize,
            actor: fertilize.user,
            toast_message: @translator.t("fertilizes.undo.toast", name: fertilize.name)
          )
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise StandardError, @translator.t("fertilizes.flash.cannot_delete_in_use")
        rescue DeletionUndo::Error => e
          raise StandardError, e.message
        end

        def visible_records(user)
          if user.admin?
            ::Fertilize.where("is_reference = ? OR user_id = ?", true, user.id)
          else
            ::Fertilize.where(user_id: user.id, is_reference: false)
          end
        end

        def find_authorized_for_view(user, id)
          fertilize = find_fertilize_model!(id)
          unless Domain::Shared::Policies::FertilizePolicy.view_allowed?(user, is_reference: fertilize.is_reference, user_id: fertilize.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          fertilize
        end

        def find_authorized_for_edit(user, id)
          fertilize = find_fertilize_model!(id)
          unless Domain::Shared::Policies::FertilizePolicy.edit_allowed?(user, is_reference: fertilize.is_reference, user_id: fertilize.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          fertilize
        end

        def find_model(id)
          find_fertilize_model!(id)
        end

        def create_for_user(user, attrs)
          h = Domain::Shared::Policies::FertilizePolicy.normalize_attrs_for_create(user, attrs)
          fertilize = ::Fertilize.new(h)
          raise StandardError, fertilize.errors.full_messages.join(", ") unless fertilize.save

          fertilize
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
          raise StandardError, fertilize.errors.full_messages.join(", ") unless fertilize.update(normalized)

          fertilize.reload
        end

        def list_from_relation(relation)
          relation.map { |record| Domain::Fertilize::Entities::FertilizeEntity.from_model(record) }
        end

        private

        def find_fertilize_model!(id)
          ::Fertilize.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
