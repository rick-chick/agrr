# frozen_string_literal: true

module Api
  module V1
    module Masters
      module Crops
        # 作物と害虫の関連管理API
        #
        # @example 作物に紐づく害虫一覧の取得
        #   GET /api/v1/masters/crops/:crop_id/pests
        #   Headers: X-API-Key: <api_key>
        #
        # @example 作物に害虫を関連付け
        #   POST /api/v1/masters/crops/:crop_id/pests
        #   Headers: X-API-Key: <api_key>
        #   Body: { "pest_id": 123 }
        #
        # @example 作物から害虫の関連を削除
        #   DELETE /api/v1/masters/crops/:crop_id/pests/:pest_id
        #   Headers: X-API-Key: <api_key>
        #
        # @note 認証: APIキー認証が必要です（X-API-KeyヘッダーまたはAuthorization: Bearer <api_key>）
        # @note 権限: ユーザーは自分の所有する作物のみアクセス可能です
        class PestsController < BaseController
          before_action :set_crop
          before_action :set_pest, only: [:destroy]

          # 作物に紐づく害虫一覧を取得
          #
          # @param crop_id [Integer] 作物ID
          # @return [Array<Pest>] 作物に紐づく害虫の配列
          # @return [200] 成功
          # @return [401] APIキーが無効
          # @return [404] 作物が見つからない
          def index
            # Policy経由で選択可能な害虫のみ表示（参照害虫も含む）
            accessible_pest_ids = Domain::Shared::Policies::PestPolicy.selectable_scope(Pest, current_user).pluck(:id)
            @pests = @crop.pests.where(id: accessible_pest_ids)
            render json: @pests
          end

          # 作物に害虫を関連付け
          #
          # @param crop_id [Integer] 作物ID
          # @param pest_id [Integer] 害虫ID
          # @return [Hash] 関連付け成功のメッセージ
          # @return [201] 関連付け成功
          # @return [401] APIキーが無効
          # @return [404] 作物または害虫が見つからない
          # @return [422] 既に関連付けられている、またはバリデーションエラー
          def create
            pest_id = params[:pest_id]
            
            unless pest_id.present?
              render json: { error: I18n.t('api.errors.pests.pest_id_required') }, status: :unprocessable_entity
              return
            end

            pest = Pest.find_by(id: pest_id)
            unless pest
              render json: { error: I18n.t('api.errors.pests.not_found') }, status: :not_found
              return
            end

            # 権限チェック: Policy経由で関連付け可否を判定（参照害虫も含む）
            unless Domain::Shared::Policies::PestPolicy.selectable_scope(Pest, current_user).exists?(id: pest.id)
              render json: { error: I18n.t('api.errors.pests.permission_denied') }, status: :forbidden
              return
            end

            # 既に関連付けられているかチェック
            if @crop.pests.include?(pest)
              render json: { error: I18n.t('api.errors.pests.already_associated') }, status: :unprocessable_entity
              return
            end

            @crop.pests << pest
            render json: { message: I18n.t('api.messages.pests.associated_successfully'), crop_id: @crop.id, pest_id: pest.id }, status: :created
          end

          # 作物から害虫の関連を削除
          #
          # @param crop_id [Integer] 作物ID
          # @param pest_id [Integer] 害虫ID
          # @return [204] 削除成功
          # @return [401] APIキーが無効
          # @return [404] 作物または害虫が見つからない、または関連が存在しない
          def destroy
            unless @crop.pests.include?(@pest)
              render json: { error: I18n.t('api.errors.pests.not_associated') }, status: :not_found
              return
            end

            @crop.pests.delete(@pest)
            head :no_content
          end

          private

          def set_crop
            @crop = Domain::Shared::Policies::CropPolicy.visible_scope(::Crop, current_user).where(is_reference: false).find(params[:crop_id])
          rescue ActiveRecord::RecordNotFound
            render json: { error: I18n.t('api.errors.crop_not_found') }, status: :not_found
          end

          def set_pest
            @pest = Pest.find_by(id: params[:id])
            unless @pest
              render json: { error: I18n.t('api.errors.pests.not_found') }, status: :not_found
            end
          end
        end
      end
    end
  end
end
