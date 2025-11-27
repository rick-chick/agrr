# frozen_string_literal: true

module Api
  module V1
    module Masters
      module Crops
        # 作物と生育ステージの関連管理API
        #
        # @example 作物に紐づく生育ステージ一覧の取得
        #   GET /api/v1/masters/crops/:crop_id/crop_stages
        #   Headers: X-API-Key: <api_key>
        #
        # @example 作物に生育ステージを作成
        #   POST /api/v1/masters/crops/:crop_id/crop_stages
        #   Headers: X-API-Key: <api_key>
        #   Body: { "crop_stage": { "name": "発芽期", "order": 1 } }
        #
        # @example 生育ステージを更新
        #   PATCH /api/v1/masters/crops/:crop_id/crop_stages/:id
        #   Headers: X-API-Key: <api_key>
        #   Body: { "crop_stage": { "name": "更新された名前" } }
        #
        # @example 生育ステージを削除
        #   DELETE /api/v1/masters/crops/:crop_id/crop_stages/:id
        #   Headers: X-API-Key: <api_key>
        #
        # @note 認証: APIキー認証が必要です（X-API-KeyヘッダーまたはAuthorization: Bearer <api_key>）
        # @note 権限: ユーザーは自分の所有する作物のみアクセス可能です
        class CropStagesController < BaseController
          before_action :set_crop
          before_action :set_crop_stage, only: [:show, :update, :destroy]

          # 作物に紐づく生育ステージ一覧を取得
          #
          # @param crop_id [Integer] 作物ID
          # @return [Array<CropStage>] 作物に紐づく生育ステージの配列
          # @return [200] 成功
          # @return [401] APIキーが無効
          # @return [404] 作物が見つからない
          def index
            @crop_stages = @crop.crop_stages.order(:order)
            render json: @crop_stages
          end

          # 生育ステージの詳細を取得
          #
          # @param crop_id [Integer] 作物ID
          # @param id [Integer] 生育ステージID
          # @return [CropStage] 生育ステージオブジェクト
          # @return [200] 成功
          # @return [401] APIキーが無効
          # @return [404] 作物または生育ステージが見つからない
          def show
            render json: @crop_stage
          end

          # 作物に生育ステージを作成
          #
          # @param crop_id [Integer] 作物ID
          # @param crop_stage [Hash] 生育ステージのパラメータ
          # @param crop_stage[name] [String] ステージ名（必須）
          # @param crop_stage[order] [Integer] 順序（必須）
          # @return [CropStage] 作成された生育ステージオブジェクト
          # @return [201] 作成成功
          # @return [401] APIキーが無効
          # @return [404] 作物が見つからない
          # @return [422] バリデーションエラー
          def create
            @crop_stage = @crop.crop_stages.build(crop_stage_params)

            if @crop_stage.save
              render json: @crop_stage, status: :created
            else
              render json: { errors: @crop_stage.errors.full_messages }, status: :unprocessable_entity
            end
          end

          # 生育ステージを更新
          #
          # @param crop_id [Integer] 作物ID
          # @param id [Integer] 生育ステージID
          # @param crop_stage [Hash] 更新する生育ステージのパラメータ
          # @return [CropStage] 更新された生育ステージオブジェクト
          # @return [200] 更新成功
          # @return [401] APIキーが無効
          # @return [404] 作物または生育ステージが見つからない
          # @return [422] バリデーションエラー
          def update
            if @crop_stage.update(crop_stage_params)
              render json: @crop_stage
            else
              render json: { errors: @crop_stage.errors.full_messages }, status: :unprocessable_entity
            end
          end

          # 生育ステージを削除
          #
          # @param crop_id [Integer] 作物ID
          # @param id [Integer] 生育ステージID
          # @return [204] 削除成功
          # @return [401] APIキーが無効
          # @return [404] 作物または生育ステージが見つからない
          # @return [422] 削除エラー
          def destroy
            if @crop_stage.destroy
              head :no_content
            else
              render json: { errors: @crop_stage.errors.full_messages }, status: :unprocessable_entity
            end
          end

          private

          def set_crop
            @crop = CropPolicy.visible_scope(current_user).where(is_reference: false).find(params[:crop_id])
          rescue ActiveRecord::RecordNotFound
            render json: { error: 'Crop not found' }, status: :not_found
          end

          def set_crop_stage
            @crop_stage = @crop.crop_stages.find(params[:id])
          rescue ActiveRecord::RecordNotFound
            render json: { error: 'CropStage not found' }, status: :not_found
          end

          def crop_stage_params
            params.require(:crop_stage).permit(:name, :order)
          end
        end
      end
    end
  end
end
