# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropToggleTaskTemplateInteractor
        def initialize(output_port:, user_id:, crop_id:, agricultural_task_id:, gateway:, agricultural_task_gateway:, toggle_gateway:, translator:, logger:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @crop_id = crop_id
          @agricultural_task_id = agricultural_task_id
          @gateway = gateway
          @agricultural_task_gateway = agricultural_task_gateway
          @toggle_gateway = toggle_gateway
          @translator = translator
          @logger = logger
          @user_lookup = user_lookup
        end

        def call
          user = begin
            @user_lookup.find(@user_id)
          rescue Domain::Shared::Exceptions::RecordNotFound => e
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
            return
          end

          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)

          begin
            @gateway.find_authorized_for_edit(user, @crop_id, access_filter: access_filter)
          rescue Domain::Shared::Exceptions::RecordNotFound
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("crops.flash.not_found")))
            return
          end

          begin
            @agricultural_task_gateway.find_model(@agricultural_task_id)
          rescue Domain::Shared::Exceptions::RecordNotFound
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("crops.flash.task_not_found")))
            return
          end

          result = @toggle_gateway.toggle_build_snapshot!(crop_id: @crop_id, agricultural_task_id: @agricultural_task_id)
          @output_port.on_success(result)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
