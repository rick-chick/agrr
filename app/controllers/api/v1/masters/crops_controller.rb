# frozen_string_literal: true

module Api
  module V1
    module Masters
      # 作物（Crop）マスタ管理API
      #
      # @example 作物一覧の取得
      #   GET /api/v1/masters/crops
      #   Headers: X-API-Key: <api_key>
      #
      # @example 作物の作成
      #   POST /api/v1/masters/crops
      #   Headers: X-API-Key: <api_key>
      #   Body: { "crop": { "name": "トマト", "variety": "桃太郎", "area_per_unit": 0.5, "revenue_per_area": 8000.0 } }
      #
      # @example 作物の更新
      #   PATCH /api/v1/masters/crops/:id
      #   Headers: X-API-Key: <api_key>
      #   Body: { "crop": { "name": "更新された名前" } }
      #
      # @example 作物の削除
      #   DELETE /api/v1/masters/crops/:id
      #   Headers: X-API-Key: <api_key>
      #
      # @note 認証: APIキー認証が必要です（X-API-KeyヘッダーまたはAuthorization: Bearer <api_key>）
      # @note 権限: ユーザーは自分の所有する作物のみアクセス可能です
      class CropsController < BaseController
        before_action :set_crop, only: [:show, :update, :destroy]

        # 作物一覧を取得
        #
        # @return [Array<Crop>] ユーザーが所有する作物の配列
        # @return [200] 成功
        # @return [401] APIキーが無効
        def index
          @crops = current_user.crops.where(is_reference: false)
          render json: @crops
        end

        # 作物の詳細を取得
        #
        # @param id [Integer] 作物ID
        # @return [Crop] 作物オブジェクト
        # @return [200] 成功
        # @return [401] APIキーが無効
        # @return [404] 作物が見つからない
        def show
          render json: @crop
        end

        # 作物を作成
        #
        # @param crop [Hash] 作物のパラメータ
        # @param crop[name] [String] 作物名（必須）
        # @param crop[variety] [String] 品種名（任意）
        # @param crop[area_per_unit] [Float] 単位あたりの栽培面積（㎡、任意）
        # @param crop[revenue_per_area] [Float] 面積あたりの収益（円/㎡、任意）
        # @param crop[region] [String] 地域（任意）
        # @param crop[groups] [Array<String>] 作物グループ（任意）
        # @return [Crop] 作成された作物オブジェクト
        # @return [201] 作成成功
        # @return [401] APIキーが無効
        # @return [422] バリデーションエラー
        def create
          @crop = current_user.crops.build(crop_params)
          @crop.is_reference = false

          if @crop.save
            render json: @crop, status: :created
          else
            render json: { errors: @crop.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # 作物を更新
        #
        # @param id [Integer] 作物ID
        # @param crop [Hash] 更新する作物のパラメータ
        # @return [Crop] 更新された作物オブジェクト
        # @return [200] 更新成功
        # @return [401] APIキーが無効
        # @return [404] 作物が見つからない
        # @return [422] バリデーションエラー
        def update
          if @crop.update(crop_params)
            render json: @crop
          else
            render json: { errors: @crop.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # 作物を削除
        #
        # @param id [Integer] 作物ID
        # @return [204] 削除成功
        # @return [401] APIキーが無効
        # @return [404] 作物が見つからない
        # @return [422] 削除エラー
        def destroy
          if @crop.destroy
            head :no_content
          else
            render json: { errors: @crop.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_crop
          @crop = current_user.crops.where(is_reference: false).find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Crop not found' }, status: :not_found
        end

        def crop_params
          params.require(:crop).permit(:name, :variety, :area_per_unit, :revenue_per_area, :region, groups: [])
        end
      end
    end
  end
end
