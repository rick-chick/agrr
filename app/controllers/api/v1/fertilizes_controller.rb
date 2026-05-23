# frozen_string_literal: true

module Api
  module V1
    class FertilizesController < Api::V1::BaseController
      # ai_createは認証不要（無料プラン機能の一部）
      # ai_updateはHTMLフォームから呼び出すため認証必須
      skip_before_action :authenticate_api_request, only: [ :ai_create ]
      before_action :authenticate_api_request, only: [ :ai_update ]

      # POST /api/v1/fertilizes/ai_create
      # AIで肥料情報を取得して保存
      def ai_create
        presenter = Adapters::Fertilize::Presenters::FertilizeAiCreateApiPresenter.new(view: self)
        CompositionRoot.fertilize_ai_create_interactor(current_user: current_user, output_port: presenter).call(
          fertilize_query_name: params[:name]
        )
      end

      # POST /api/v1/fertilizes/:id/ai_update
      # AIで肥料情報を取得して更新（編集時は既存を編集）
      def ai_update
        result = CompositionRoot.fertilize_ai_update_interactor(current_user: current_user).call(
          fertilize_id: params[:id],
          fertilize_query_name: params[:name]
        )
        render json: result.body, status: result.status
      end

      def render_response(json:, status:)
        render json: json, status: status
      end
    end
  end
end
