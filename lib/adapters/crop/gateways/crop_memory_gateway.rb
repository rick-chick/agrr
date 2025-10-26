# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      class CropMemoryGateway < Domain::Crop::Gateways::CropGateway
        def find_by_id(id)
          record = ::Crop.includes(crop_stages: [:temperature_requirement, :sunshine_requirement, :thermal_requirement]).find_by(id: id)
          return nil unless record
          entity_from_record(record)
        end

        def find_all_visible_for(user_id)
          scope = ::Crop.includes(crop_stages: [:temperature_requirement, :sunshine_requirement, :thermal_requirement])
          scope = scope.where("is_reference = ? OR user_id = ?", true, user_id)
          scope.map { |record| entity_from_record(record) }
        end

        def create(crop_data)
          record = ::Crop.new(
            user_id: crop_data[:user_id],
            name: crop_data[:name],
            variety: crop_data[:variety],
            is_reference: crop_data.fetch(:is_reference, false),
            area_per_unit: crop_data[:area_per_unit],
            revenue_per_area: crop_data[:revenue_per_area],
            groups: crop_data[:groups] || []
          )
          
          unless record.save
            error_message = record.errors.full_messages.join(', ')
            raise StandardError, error_message
          end
          
          entity_from_record(record)
        end

        def update(id, crop_data)
          record = ::Crop.find(id)
          update_attributes = {}
          update_attributes[:name] = crop_data[:name] if crop_data.key?(:name)
          update_attributes[:variety] = crop_data[:variety] if crop_data.key?(:variety)
          update_attributes[:is_reference] = crop_data[:is_reference] if crop_data.key?(:is_reference)
          update_attributes[:area_per_unit] = crop_data[:area_per_unit] if crop_data.key?(:area_per_unit)
          update_attributes[:revenue_per_area] = crop_data[:revenue_per_area] if crop_data.key?(:revenue_per_area)
          update_attributes[:groups] = crop_data[:groups] if crop_data.key?(:groups)
          record.update!(update_attributes)
          entity_from_record(record.reload)
        end

        def delete(id)
          record = ::Crop.find(id)
          record.destroy!
          true
        rescue ActiveRecord::RecordNotFound
          false
        end

        def exists?(id)
          ::Crop.exists?(id: id)
        end

        private

        def entity_from_record(record)
          stage_entities = record.crop_stages.order(:order).map do |stage|
            Domain::Crop::Entities::CropStageEntity.new(
              id: stage.id,
              crop_id: record.id,
              name: stage.name,
              order: stage.order,
              temperature: stage.temperature_requirement && {
                base_temperature: stage.temperature_requirement.base_temperature,
                optimal_min: stage.temperature_requirement.optimal_min,
                optimal_max: stage.temperature_requirement.optimal_max,
                low_stress_threshold: stage.temperature_requirement.low_stress_threshold,
                high_stress_threshold: stage.temperature_requirement.high_stress_threshold,
                frost_threshold: stage.temperature_requirement.frost_threshold,
                sterility_risk_threshold: stage.temperature_requirement.sterility_risk_threshold
              },
              sunshine: stage.sunshine_requirement && {
                minimum_sunshine_hours: stage.sunshine_requirement.minimum_sunshine_hours,
                target_sunshine_hours: stage.sunshine_requirement.target_sunshine_hours
              },
              thermal: stage.thermal_requirement && {
                required_gdd: stage.thermal_requirement.required_gdd
              }
            )
          end

          Domain::Crop::Entities::CropEntity.new(
            id: record.id,
            user_id: record.user_id,
            name: record.name,
            variety: record.variety,
            is_reference: record.is_reference,
            area_per_unit: record.area_per_unit,
            revenue_per_area: record.revenue_per_area,
            groups: record.groups,
            created_at: record.created_at,
            updated_at: record.updated_at
          ).tap do |entity|
            # attach stages array for aggregation access pattern
            entity.instance_variable_set(:@stages, stage_entities)
            def entity.stages; @stages; end
          end
        end
      end
    end
  end
end


