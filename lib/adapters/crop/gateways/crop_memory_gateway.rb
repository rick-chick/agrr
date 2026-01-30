# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      class CropMemoryGateway < Domain::Crop::Gateways::CropGateway
        def list(scope = nil)
          query = scope || ::Crop.all
          query.map { |record| Domain::Crop::Entities::CropEntity.from_model(record) }
        end

        def find_by_id(crop_id)
          crop = ::Crop.find(crop_id)
          Domain::Crop::Entities::CropEntity.from_model(crop)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'Crop not found'
        end

        def create(create_input_dto)
          crop_attributes = {
            name: create_input_dto.name,
            variety: create_input_dto.variety,
            area_per_unit: create_input_dto.area_per_unit,
            revenue_per_area: create_input_dto.revenue_per_area,
            region: create_input_dto.region,
            groups: create_input_dto.groups || []
          }
          crop_attributes[:crop_stages_attributes] = create_input_dto.crop_stages_attributes if create_input_dto.crop_stages_attributes.present?

          crop = ::Crop.new(crop_attributes)
          raise StandardError, crop.errors.full_messages.join(', ') unless crop.save

          Domain::Crop::Entities::CropEntity.from_model(crop)
        end

        def update(crop_id, update_input_dto)
          crop = ::Crop.find(crop_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:variety] = update_input_dto.variety if !update_input_dto.variety.nil?
          attrs[:area_per_unit] = update_input_dto.area_per_unit if !update_input_dto.area_per_unit.nil?
          attrs[:revenue_per_area] = update_input_dto.revenue_per_area if !update_input_dto.revenue_per_area.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?
          attrs[:groups] = update_input_dto.groups if !update_input_dto.groups.nil?
          attrs[:crop_stages_attributes] = update_input_dto.crop_stages_attributes if update_input_dto.crop_stages_attributes.present?

          crop.update(attrs)
          raise StandardError, crop.errors.full_messages.join(', ') if crop.errors.any?

          Domain::Crop::Entities::CropEntity.from_model(crop.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'Crop not found'
        end

      end
    end
  end
end


