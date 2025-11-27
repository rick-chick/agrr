# frozen_string_literal: true

module Api
  module V1
    module Masters
      module Crops
        # 作物に紐づく農薬一覧取得API
        #
        # @example 作物に紐づく農薬一覧の取得
        #   GET /api/v1/masters/crops/:crop_id/pesticides
        #   Headers: X-API-Key: <api_key>
        #
        # @note 認証: APIキー認証が必要です（X-API-KeyヘッダーまたはAuthorization: Bearer <api_key>）
        # @note 権限: ユーザーは自分の所有する作物のみアクセス可能です
        # @note 農薬の作成・更新・削除は /api/v1/masters/pesticides を使用してください
        class PesticidesController < BaseController
          before_action :set_crop

          # 作物に紐づく農薬一覧を取得
          #
          # @param crop_id [Integer] 作物ID
          # @return [Array<Pesticide>] 作物に紐づく農薬の配列
          # @return [200] 成功
          # @return [401] APIキーが無効
          # @return [404] 作物が見つからない
          def index
            # Policy経由で選択可能な農薬のみ表示（参照農薬も含む）
            accessible_pesticide_ids = PesticidePolicy.selectable_scope(current_user).pluck(:id)
            @pesticides = Pesticide.where(crop_id: @crop.id, id: accessible_pesticide_ids).recent
            render json: @pesticides
          end

          private

          def set_crop
            @crop = CropPolicy.visible_scope(current_user).where(is_reference: false).find(params[:crop_id])
          rescue ActiveRecord::RecordNotFound
            render json: { error: 'Crop not found' }, status: :not_found
          end
        end
      end
    end
  end
end
