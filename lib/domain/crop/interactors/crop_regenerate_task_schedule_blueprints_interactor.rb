# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropRegenerateTaskScheduleBlueprintsInteractor
        def initialize(output_port:, user_id:, crop_id:, gateway:, blueprint_regeneration_gateway:, translator:, logger:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @crop_id = crop_id
          @gateway = gateway
          @blueprint_regeneration_gateway = blueprint_regeneration_gateway
          @translator = translator
          @logger = logger
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          crop = @gateway.find_authorized_model_for_edit(user, @crop_id)
          @blueprint_regeneration_gateway.regenerate_from_crop!(crop: crop)
          @output_port.on_success
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue Domain::Crop::Exceptions::MissingTaskTemplatesForBlueprintRegeneration,
               Domain::Crop::Exceptions::BlueprintRegenerationFromAgrrFailed => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          log_interactor_error(e)
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("crops.flash.task_schedule_blueprints_failed")))
        end

        private

        def log_interactor_error(error)
          @logger.error(
            "[CropRegenerateTaskScheduleBlueprintsInteractor] #{error.class}: #{error.message}\n#{error.full_message}"
          )
        end
      end
    end
  end
end
