# frozen_string_literal: true

module Api
  module V1
    class PestsController < Api::V1::BaseController
      # ai_createは認証不要（無料プラン機能の一部）
      # ai_updateはHTMLフォームから呼び出すため認証必須
      skip_before_action :authenticate_api_request, only: [ :ai_create ]
      before_action :authenticate_api_request, only: [ :ai_update ]

      # POST /api/v1/pests/ai_create
      # AIで害虫情報を取得して保存
      def ai_create
        result = CompositionRoot.pest_ai_create_interactor(current_user: current_user).call(
          pest_name: params[:name],
          affected_crops: pest_ai_create_affected_crops_from_params
        )
        render json: result.body, status: result.status
      end

      # POST /api/v1/pests/:id/ai_update
      # AIで害虫情報を取得して更新（編集時は既存を編集）
      def ai_update
        result = CompositionRoot.pest_ai_update_interactor(current_user: current_user).call(
          pest_id: params[:id],
          pest_query_name: params[:name]
        )
        render json: result.body, status: result.status
      end

      private

      def pest_ai_create_affected_crops_from_params
        raw = params[:affected_crops] || []
        return [] unless raw.is_a?(Array)

        raw.map do |c|
          case c
          when ActionController::Parameters
            c.permit(:crop_id, :crop_name).to_h
          when Hash
            c.symbolize_keys
          else
            c.to_h if c.respond_to?(:to_h)
          end
        end.compact
      end
    end
  end
end
