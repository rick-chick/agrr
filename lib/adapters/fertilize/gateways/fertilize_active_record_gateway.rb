# frozen_string_literal: true

module Adapters
  module Fertilize
    module Gateways
      class FertilizeActiveRecordGateway < Domain::Fertilize::Gateways::FertilizeGateway
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
          raise StandardError, fertilize.errors.full_messages.join(', ') unless fertilize.save

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
          raise StandardError, fertilize.errors.full_messages.join(', ') unless fertilize.update(attrs)

          Domain::Fertilize::Entities::FertilizeEntity.from_model(fertilize.reload)
        end

        def destroy(fertilize_id)
          fertilize = ::Fertilize.find(fertilize_id)
          DeletionUndo::Manager.schedule(
            record: fertilize,
            actor: fertilize.user,
            toast_message: I18n.t('fertilizes.undo.toast', name: fertilize.name)
          )
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise StandardError, I18n.t('fertilizes.flash.cannot_delete_in_use')
        rescue DeletionUndo::Error => e
          raise StandardError, e.message
        end
      end
    end
  end
end