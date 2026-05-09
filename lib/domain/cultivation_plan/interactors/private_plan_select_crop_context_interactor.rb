# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class PrivatePlanSelectCropContextInteractor
        def initialize(output_port:, user_id:, farm_id:, field_gateway:, crop_gateway:, translator:, logger:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @farm_id = farm_id
          @field_gateway = field_gateway
          @crop_gateway = crop_gateway
          @translator = translator
          @logger = logger
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          # 農場＋圃場は FieldGateway 1 経路で取得（view 用の farm find と二重に叩かない）
          fields_result = @field_gateway.authorized_farm_fields_list(
            @farm_id,
            farm_access_filter: Domain::Shared::Policies::FarmPolicy.record_access_filter(user)
          )
          farm = fields_result.farm
          total_area = fields_result.fields.sum { |f| f.area.to_f }
          crops = @crop_gateway.list_user_owned_non_reference_crops_ordered_by_name(user)
          plan_name = farm.name.to_s
          dto = Domain::CultivationPlan::Dtos::PrivatePlanSelectCropContextDto.new(
            farm: farm,
            plan_name: plan_name,
            crops: crops,
            total_area: total_area
          )
          @output_port.on_success(dto)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.farm_not_found")))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.error("[PrivatePlanSelectCropContextInteractor] record_invalid: #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
