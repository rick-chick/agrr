# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # `PlansController#load_private_plan_select_crop_context` と同等の呼び出しをカプセル化（Controller から AR・二重取得を排除）。
    class PrivatePlanSelectCropHtmlContextRunner
      def initialize(view:, user_id:, field_gateway:, crop_gateway:, translator:, logger:, user_lookup:)
        @view = view
        @user_id = user_id
        @field_gateway = field_gateway
        @crop_gateway = crop_gateway
        @translator = translator
        @logger = logger
        @user_lookup = user_lookup
      end

      def call(farm_id:)
        presenter = Presenters::Html::Plans::PrivatePlanSelectCropHtmlPresenter.new(view: @view)
        Domain::CultivationPlan::Interactors::PrivatePlanSelectCropContextInteractor.new(
          output_port: presenter,
          user_id: @user_id,
          farm_id: farm_id,
          field_gateway: @field_gateway,
          crop_gateway: @crop_gateway,
          translator: @translator,
          logger: @logger,
          user_lookup: @user_lookup
        ).call
      end

      def response_committed?
        @view.performed?
      end
    end
  end
end
