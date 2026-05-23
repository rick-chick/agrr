# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      # agrr から作物情報を取得し、永続化（upsert）まで行う。
      class CropAiCreateInteractor
        def initialize(
          output_port:,
          user_id:,
          user_lookup:,
          translator:,
          logger:,
          crop_ai_query_gateway:,
          persistence:
        )
          @output_port = output_port
          @user_id = user_id
          @user_lookup = user_lookup
          @translator = translator
          @logger = logger
          @crop_ai_query_gateway = crop_ai_query_gateway
          @persistence = persistence
        end

        def call(crop_name:, variety: nil)
          user = @user_lookup.find(@user_id)
          if user.anonymous?
            return @output_port.on_failure(
              Domain::Crop::Dtos::CropAiCreateFailure.new(
                http_status: :unauthorized,
                message: @translator.t("auth.api.login_required")
              )
            )
          end

          cn = crop_name&.strip
          if cn.nil? || cn.empty?
            return @output_port.on_failure(
              Domain::Crop::Dtos::CropAiCreateFailure.new(
                http_status: :bad_request,
                message: @translator.t("api.errors.crops.name_required")
              )
            )
          end

          v = variety&.strip
          v = nil if v.nil? || v.empty?

          crop_info, agrr_failure = @crop_ai_query_gateway.fetch_crop_json(cn)
          if agrr_failure
            return @output_port.on_failure(
              Domain::Crop::Dtos::CropAiCreateFailure.new(
                http_status: agrr_failure.fetch(:status),
                message: agrr_failure.fetch(:message)
              )
            )
          end

          result = @persistence.upsert(
            user_dto: user,
            crop_name: cn,
            variety: v,
            crop_info: crop_info,
            crop_access_filter: Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          )

          if result.is_a?(Domain::Crop::Dtos::CropAiCreateFailure)
            @output_port.on_failure(result)
          else
            @output_port.on_success(result)
          end
        end
      end
    end
  end
end
