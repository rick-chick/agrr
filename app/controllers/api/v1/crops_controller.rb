# frozen_string_literal: true

module Api
  module V1
    class CropsController < Api::V1::BaseController
      # ai_createは認証不要（無料プラン機能の一部）
      skip_before_action :authenticate_api_request, only: [ :ai_create ]
      before_action :set_interactors, only: [ :ai_create ]

      # POST /api/v1/crops/ai_create
      # AIで作物情報を取得して保存
      def ai_create
        crop_name = params[:name]&.strip
        variety = params[:variety]&.strip

        unless crop_name.present?
          return render json: { error: I18n.t("api.errors.crops.name_required") }, status: :bad_request
        end

        crop_info, agrr_failure = CompositionRoot.crop_ai_daemon_query_gateway.fetch_crop_json(crop_name)
        if agrr_failure
          return render json: { error: agrr_failure.fetch(:message) }, status: agrr_failure.fetch(:status)
        end

        service = CropAiUpsertService.new(
          user: current_user,
          create_interactor: @create_interactor,
          crop_gateway: CompositionRoot.crop_gateway
        )

        result = service.call(crop_name: crop_name, variety: variety, crop_info: crop_info)
        render json: result.body, status: result.status
      end

      private

      def set_interactors
        @create_interactor = CompositionRoot.crop_create_for_ai_adapter(user_id: current_user.id)
      end
    end
  end
end
