# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      # agrr から作物情報を取得し、永続化（upsert）まで行う。
      class CropAiCreateInteractor
        def initialize(
          user_id:,
          user_lookup:,
          translator:,
          logger:,
          crop_ai_query_gateway:,
          persistence:
        )
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
            return Domain::Shared::Dtos::HttpJsonEnvelope.new(
              status: :unauthorized,
              body: { error: @translator.t("auth.api.login_required") }
            )
          end

          cn = crop_name&.strip
          if cn.nil? || cn.empty?
            return Domain::Shared::Dtos::HttpJsonEnvelope.new(
              status: :bad_request,
              body: { error: @translator.t("api.errors.crops.name_required") }
            )
          end

          v = variety&.strip
          v = nil if v.nil? || v.empty?

          crop_info, agrr_failure = @crop_ai_query_gateway.fetch_crop_json(cn)
          if agrr_failure
            return Domain::Shared::Dtos::HttpJsonEnvelope.new(
              status: agrr_failure.fetch(:status),
              body: { error: agrr_failure.fetch(:message) }
            )
          end

          @persistence.upsert(user_dto: user, crop_name: cn, variety: v, crop_info: crop_info)
        end
      end
    end
  end
end
