# frozen_string_literal: true

module Adapters
  module Pesticide
    module Gateways
      class PesticideActiveRecordGateway < Domain::Pesticide::Gateways::PesticideGateway
        def list
          ::Pesticide.all.map { |record| Domain::Pesticide::Entities::PesticideEntity.from_model(record) }
        end

        def find_by_id(pesticide_id)
          pesticide = ::Pesticide.find(pesticide_id)
          Domain::Pesticide::Entities::PesticideEntity.from_model(pesticide)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'Pesticide not found'
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
          raise StandardError, pesticide.errors.full_messages.join(', ') unless pesticide.save

          Domain::Pesticide::Entities::PesticideEntity.from_model(pesticide)
        end

        def update(pesticide_id, update_input_dto)
          pesticide = ::Pesticide.find(pesticide_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:active_ingredient] = update_input_dto.active_ingredient if !update_input_dto.active_ingredient.nil?
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:crop_id] = update_input_dto.crop_id if !update_input_dto.crop_id.nil?
          attrs[:pest_id] = update_input_dto.pest_id if !update_input_dto.pest_id.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?

          pesticide.update(attrs)
          raise StandardError, pesticide.errors.full_messages.join(', ') if pesticide.errors.any?

          Domain::Pesticide::Entities::PesticideEntity.from_model(pesticide.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'Pesticide not found'
        end

        def destroy(pesticide_id)
          pesticide = ::Pesticide.find(pesticide_id)
          # DeletionUndo scheduling is handled in the interactor layer
          pesticide.destroy!
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'Pesticide not found'
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise StandardError, I18n.t('pesticides.flash.cannot_delete_in_use')
        end
      end
    end
  end
end
