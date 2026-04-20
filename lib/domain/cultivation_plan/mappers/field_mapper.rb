# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      class FieldMapper
        def initialize(ctx)
          @ctx = ctx
        end

        def create_user_fields(farm)
          if @ctx.farm_reused
            Rails.logger.info "♻️ [PlanSaveService] Skipping field creation because farm was reused"
            existing_fields = farm.fields.where(user: @ctx.user).order(:id).to_a
            existing_fields.each { |field| @ctx.result.add_skip(:fields, field.id) }
            return existing_fields
          end

          field_data = @ctx.session_data[:field_data] || @ctx.session_data["field_data"]
          Rails.logger.debug I18n.t("services.plan_save_service.debug.field_data_extracted", field_data: field_data.inspect)

          return [] unless field_data&.any?

          user_fields = []

          field_data.each do |field_info|
            Rails.logger.debug "🔍 [PlanSaveService] Processing field_info: #{field_info.inspect}"

            field_name = field_info[:name] || field_info["name"]
            field_area = field_info[:area] || field_info["area"]
            field_coordinates = field_info[:coordinates] || field_info["coordinates"]

            Rails.logger.debug "🔍 [PlanSaveService] Extracted: name=#{field_name}, area=#{field_area}, coordinates=#{field_coordinates}"

            field_attrs = {
              farm: farm,
              user: @ctx.user,
              name: field_name,
              area: field_area
            }

            if field_coordinates&.is_a?(Array) && field_coordinates.length >= 2
              field_attrs[:description] = I18n.t("services.plan_save_service.messages.coordinates", lat: field_coordinates[0], lng: field_coordinates[1])
            end

            Rails.logger.debug "🔍 [PlanSaveService] Creating field with attrs: #{field_attrs.inspect}"

            new_field = farm.fields.create!(field_attrs)
            user_fields << new_field
            Rails.logger.info I18n.t("services.plan_save_service.messages.field_created", field_name: new_field.name)
          end

          Rails.logger.info I18n.t("services.plan_save_service.debug.user_fields_created", count: user_fields.count)
          user_fields
        end
      end
    end
  end
end
