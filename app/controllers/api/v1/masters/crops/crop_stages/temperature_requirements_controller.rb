# frozen_string_literal: true

module Api
  module V1
    module Masters
      module Crops
        module CropStages
          # 生育ステージと温度要件の関連管理API
          #
          # @example 温度要件の取得
          #   GET /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/temperature_requirement
          #   Headers: X-API-Key: <api_key>
          #
          # @note 認証: APIキー認証が必要です（X-API-KeyヘッダーまたはAuthorization: Bearer <api_key>）
          # @note 権限: ユーザーは自分の所有する作物のみアクセス可能です
          class TemperatureRequirementsController < BaseController
            before_action :set_crop
            before_action :set_crop_stage

            # 温度要件を取得
            #
            # @param crop_id [Integer] 作物ID
            # @param crop_stage_id [Integer] 生育ステージID
            # @return [TemperatureRequirement] 温度要件オブジェクト（存在しない場合は404）
            # @return [200] 成功
            # @return [401] APIキーが無効
            # @return [404] 作物、生育ステージ、または温度要件が見つからない
            def show
              @requirement = @crop_stage.temperature_requirement
              if @requirement
                render json: @requirement
              else
                render json: { error: 'TemperatureRequirement not found' }, status: :not_found
              end
            end

            # 温度要件を作成
            #
            # @param crop_id [Integer] 作物ID
            # @param crop_stage_id [Integer] 生育ステージID
            # @param temperature_requirement [Hash] 温度要件のパラメータ
            # @return [TemperatureRequirement] 作成された温度要件オブジェクト
            # @return [201] 作成成功
            # @return [401] APIキーが無効
            # @return [404] 作物または生育ステージが見つからない
            # @return [422] バリデーションエラー
            def create
              if @crop_stage.temperature_requirement
                render json: { error: 'TemperatureRequirement already exists' }, status: :unprocessable_entity
                return
              end

              @requirement = @crop_stage.build_temperature_requirement(temperature_requirement_params)

              if @requirement.save
                render json: @requirement, status: :created
              else
                render json: { errors: @requirement.errors.full_messages }, status: :unprocessable_entity
              end
            end

            # 温度要件を更新
            #
            # @param crop_id [Integer] 作物ID
            # @param crop_stage_id [Integer] 生育ステージID
            # @param temperature_requirement [Hash] 更新する温度要件のパラメータ
            # @return [TemperatureRequirement] 更新された温度要件オブジェクト
            # @return [200] 更新成功
            # @return [401] APIキーが無効
            # @return [404] 作物、生育ステージ、または温度要件が見つからない
            # @return [422] バリデーションエラー
            def update
              @requirement = @crop_stage.temperature_requirement
              unless @requirement
                render json: { error: 'TemperatureRequirement not found' }, status: :not_found
                return
              end

              if @requirement.update(temperature_requirement_params)
                render json: @requirement
              else
                render json: { errors: @requirement.errors.full_messages }, status: :unprocessable_entity
              end
            end

            # 温度要件を削除
            #
            # @param crop_id [Integer] 作物ID
            # @param crop_stage_id [Integer] 生育ステージID
            # @return [204] 削除成功
            # @return [401] APIキーが無効
            # @return [404] 作物、生育ステージ、または温度要件が見つからない
            def destroy
              @requirement = @crop_stage.temperature_requirement
              unless @requirement
                render json: { error: 'TemperatureRequirement not found' }, status: :not_found
                return
              end

              if @requirement.destroy
                head :no_content
              else
                render json: { errors: @requirement.errors.full_messages }, status: :unprocessable_entity
              end
            end

            private

            def set_crop
              @crop = current_user.crops.where(is_reference: false).find(params[:crop_id])
            rescue ActiveRecord::RecordNotFound
              render json: { error: 'Crop not found' }, status: :not_found
            end

            def set_crop_stage
              @crop_stage = @crop.crop_stages.find(params[:crop_stage_id])
            rescue ActiveRecord::RecordNotFound
              render json: { error: 'CropStage not found' }, status: :not_found
            end

            def temperature_requirement_params
              params.require(:temperature_requirement).permit(
                :base_temperature, :optimal_min, :optimal_max,
                :low_stress_threshold, :high_stress_threshold,
                :frost_threshold, :sterility_risk_threshold, :max_temperature
              )
            end
          end
        end
      end
    end
  end
end
