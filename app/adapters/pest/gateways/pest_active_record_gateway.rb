# frozen_string_literal: true

module Adapters
  module Pest
    module Gateways
      class PestActiveRecordGateway < Domain::Pest::Gateways::PestGateway
        def initialize(deletion_undo_gateway:)
          @deletion_undo_gateway = deletion_undo_gateway
        end

        def list_index_for_filter(filter)
          index_relation_for_filter(filter).map { |record| Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(record) }
        end

        def list_pests_for_crop_filtered(crop_id:, pest_ids:, order: :recent_first)
          return [] if pest_ids.blank?

          base = ::Pest.joins(:crop_pests).where(crop_pests: { crop_id: crop_id }).where(id: pest_ids)
          ordered = case order.to_sym
                    when :recent_first then base.order(created_at: :desc)
                    when :id_asc then base.order(:id)
                    else base.order(:id)
                    end
          ordered.map { |record| Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(record) }
        end

        def create_for_user(user, attrs)
          pest = ::Pest.new(attrs.to_h.symbolize_keys)
          raise Domain::Shared::Exceptions::RecordInvalid, pest.errors.full_messages.join(", ") unless pest.save

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest)
        end

        def update_for_user(_user, id, attrs)
          pest = find_pest_model!(id)
          success = pest.update(attrs.to_h.symbolize_keys)
          if success
            success = pest.pest_temperature_profile&.valid? != false &&
                     pest.pest_thermal_requirement&.valid? != false &&
                     pest.pest_control_methods.all? { |method| method.valid? }
          end
          raise Domain::Shared::Exceptions::RecordInvalid, pest.errors.full_messages.join(", ") unless success

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest.reload)
        end

        def find_delete_usage(pest_id)
          pest = find_pest_model!(pest_id)
          usage_snapshot = Mappers::PestDeleteUsageSnapshotMapper.from_model(pest)
          Domain::Pest::Mappers::PestDeleteUsageMapper.from_snapshot(usage_snapshot)
        end

        def soft_delete_with_undo(user:, pest_id:, auto_hide_after: 5000, translator:)
          pest = find_pest_model!(pest_id)
          toast_message = translator.t("pests.undo.toast", name: pest.name)
          undo_gw = @deletion_undo_gateway
          event = undo_gw.schedule(
            resource_type: pest.class.name,
            resource_id: pest.id,
            actor_id: user.id,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after
          )
          { success: true, undo_entity: event }
        rescue Domain::Shared::Exceptions::RecordNotFound
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::Error.new(e.message) }
        end

        def find_by_id(pest_id)
          pest = ::Pest.find(pest_id)
          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Pest not found"
        end

        def create(create_input_dto)
          pest = ::Pest.new(
            name: create_input_dto.name,
            name_scientific: create_input_dto.name_scientific,
            family: create_input_dto.family,
            order: create_input_dto.order,
            description: create_input_dto.description,
            occurrence_season: create_input_dto.occurrence_season,
            region: create_input_dto.region
          )
          raise Domain::Shared::Exceptions::RecordInvalid, pest.errors.full_messages.join(", ") unless pest.save

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest)
        end

        def update(pest_id, update_input_dto)
          pest = ::Pest.find(pest_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:name_scientific] = update_input_dto.name_scientific if !update_input_dto.name_scientific.nil?
          attrs[:family] = update_input_dto.family if !update_input_dto.family.nil?
          attrs[:order] = update_input_dto.order if !update_input_dto.order.nil?
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:occurrence_season] = update_input_dto.occurrence_season if !update_input_dto.occurrence_season.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?

          pest.update(attrs)
          raise Domain::Shared::Exceptions::RecordInvalid, pest.errors.full_messages.join(", ") if pest.errors.any?

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Pest not found"
        end

        def find_by_name(user_id:, name:)
          return nil if name.blank?

          record = ::Pest.find_by(name: name, is_reference: false, user_id: user_id)
          return nil unless record

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(record)
        end

        private

        def index_relation_for_filter(filter)
          Adapters::Shared::Concerns::ReferenceIndexListFilterRelation.apply(::Pest, filter)
        end

        def find_pest_model!(id)
          ::Pest.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
