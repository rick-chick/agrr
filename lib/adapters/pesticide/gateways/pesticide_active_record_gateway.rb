# frozen_string_literal: true

module Adapters
  module Pesticide
    module Gateways
      class PesticideActiveRecordGateway < Domain::Pesticide::Gateways::PesticideGateway
        attr_accessor :translator
        def list
          ::Pesticide.all.map { |record| Domain::Pesticide::Entities::PesticideEntity.from_model(record) }
        end

        def find_by_id(pesticide_id)
          pesticide = ::Pesticide.find(pesticide_id)
          Domain::Pesticide::Entities::PesticideEntity.from_model(pesticide)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, "Pesticide not found"
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
          raise StandardError, pesticide.errors.full_messages.join(", ") unless pesticide.save

          Domain::Pesticide::Entities::PesticideEntity.from_model(pesticide)
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
          raise StandardError, pesticide.errors.full_messages.join(", ") if pesticide.errors.any?

          Domain::Pesticide::Entities::PesticideEntity.from_model(pesticide.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, "Pesticide not found"
        end

        def destroy(pesticide_id)
          pesticide = ::Pesticide.find(pesticide_id)
          # DeletionUndo scheduling is handled in the interactor layer
          pesticide.destroy!
        rescue ActiveRecord::RecordNotFound
          raise StandardError, "Pesticide not found"
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise StandardError, @translator.t("pesticides.flash.cannot_delete_in_use")
        end

        def visible_records(user)
          if user.admin?
            ::Pesticide.where("is_reference = ? OR user_id = ?", true, user.id)
          else
            ::Pesticide.where(user_id: user.id, is_reference: false)
          end
        end

        def selectable_records(user)
          ::Pesticide.where("is_reference = ? OR user_id = ?", true, user.id)
        end

        def find_authorized_for_view(user, id)
          pesticide = find_pesticide_model!(id)
          unless Domain::Shared::Policies::PesticidePolicy.view_allowed?(user, is_reference: pesticide.is_reference, user_id: pesticide.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          pesticide
        end

        def find_authorized_for_edit(user, id)
          find_authorized_for_view(user, id)
        end

        def find_model(id)
          find_pesticide_model!(id)
        end

        def create_for_user(user, attrs)
          h = Domain::Shared::Policies::PesticidePolicy.normalize_attrs_for_create(user, attrs)
          pesticide = ::Pesticide.new(h)
          raise StandardError, pesticide.errors.full_messages.join(", ") unless pesticide.save

          pesticide
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
          raise StandardError, pesticide.errors.full_messages.join(", ") unless pesticide.update(normalized)

          pesticide.reload
        end

        def list_from_relation(relation)
          relation.map { |record| Domain::Pesticide::Entities::PesticideEntity.from_model(record) }
        end

        private

        def find_pesticide_model!(id)
          ::Pesticide.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
