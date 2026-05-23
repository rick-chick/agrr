# frozen_string_literal: true

module Api
  module V1
    class CropsController < Api::V1::BaseController
      # ai_createは認証不要（無料プラン機能の一部）
      skip_before_action :authenticate_api_request, only: [ :ai_create ]

      # POST /api/v1/crops/ai_create
      # AIで作物情報を取得して保存
      def ai_create
        presenter = Adapters::Crop::Presenters::CropAiCreateApiPresenter.new(view: self)
        CompositionRoot.crop_ai_create_interactor(current_user: current_user, output_port: presenter).call(
          crop_name: params[:name],
          variety: params[:variety]
        )
      end

      def render_response(json:, status:)
        render json: json, status: status
      end
    end
  end
end
