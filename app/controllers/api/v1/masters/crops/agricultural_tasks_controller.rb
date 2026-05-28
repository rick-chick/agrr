# frozen_string_literal: true

module Api
  module V1
    module Masters
      module Crops
        # 作物と農業タスクの関連管理API
        #
        # @example 作物に紐づく農業タスク一覧の取得
        #   GET /api/v1/masters/crops/:crop_id/agricultural_tasks
        #   Headers: X-API-Key: <api_key>
        #
        # @example 作物に農業タスクを関連付け（中間テーブルの属性も含む）
        #   POST /api/v1/masters/crops/:crop_id/agricultural_tasks
        #   Headers: X-API-Key: <api_key>
        #   Body: { "agricultural_task_id": 456, "name": "タスク名", "time_per_sqm": 0.5, "description": "説明", "weather_dependency": "晴れ", "required_tools": ["道具1"], "skill_level": "初級" }
        #
        # @example 中間テーブルの属性を更新
        #   PATCH /api/v1/masters/crops/:crop_id/agricultural_tasks/:id
        #   Headers: X-API-Key: <api_key>
        #   Body: { "name": "更新されたタスク名", "time_per_sqm": 0.6 }
        #
        # @example 作物から農業タスクの関連を削除
        #   DELETE /api/v1/masters/crops/:crop_id/agricultural_tasks/:id
        #   Headers: X-API-Key: <api_key>
        #
        # @note 認証: APIキー認証が必要です（X-API-KeyヘッダーまたはAuthorization: Bearer <api_key>）
        # @note 権限: ユーザーは自分の所有する作物のみアクセス可能です
        # @note 中間テーブル: CropTaskTemplateの属性（name, time_per_sqm, description等）も管理します
        class AgriculturalTasksController < BaseController
          # 作物に紐づく農業タスク一覧を取得
          #
          # @param crop_id [Integer] 作物ID
          # @return [Array<Hash>] 作物に紐づく農業タスクの配列（中間テーブルの属性も含む）
          # @return [200] 成功
          # @return [401] APIキーが無効
          # @return [404] 作物が見つからない
          def index
            input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateIndexInput.new(
              user_id: current_user.id,
              crop_id: params[:crop_id]
            )
            presenter = Adapters::Crop::Presenters::CropMastersTaskTemplateIndexApiPresenter.new(
              view: self,
              translator: CompositionRoot.translator
            )
            interactor = Domain::Crop::Interactors::CropMastersTaskTemplateIndexInteractor.new(
              output_port: presenter,
              gateway: CompositionRoot.crop_gateway,
              user_lookup: CompositionRoot.user_lookup
            )
            interactor.call(input_dto)
          end

          # 作物に農業タスクを関連付け
          #
          # @param crop_id [Integer] 作物ID
          # @param agricultural_task_id [Integer] 農業タスクID（必須）
          # @param name [String] タスク名（中間テーブルの属性、任意）
          # @param time_per_sqm [Float] 単位面積あたりの時間（中間テーブルの属性、任意）
          # @param description [String] 説明（中間テーブルの属性、任意）
          # @param weather_dependency [String] 天候依存性（中間テーブルの属性、任意）
          # @param required_tools [Array<String>] 必要な道具（中間テーブルの属性、任意）
          # @param skill_level [String] スキルレベル（中間テーブルの属性、任意）
          # @return [Hash] 作成された関連の情報
          # @return [201] 関連付け成功
          # @return [401] APIキーが無効
          # @return [404] 作物または農業タスクが見つからない
          # @return [422] 既に関連付けられている、またはバリデーションエラー
          def create
            input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
              user_id: current_user.id,
              crop_id: params[:crop_id],
              agricultural_task_id: template_params[:agricultural_task_id],
              name: template_params[:name],
              description: template_params[:description],
              time_per_sqm: template_params[:time_per_sqm],
              weather_dependency: template_params[:weather_dependency],
              required_tools: template_params[:required_tools],
              skill_level: template_params[:skill_level]
            )
            presenter = Adapters::Crop::Presenters::CropMastersTaskTemplateCreateApiPresenter.new(
              view: self,
              translator: CompositionRoot.translator
            )
            interactor = Domain::Crop::Interactors::CropMastersTaskTemplateCreateInteractor.new(
              output_port: presenter,
              gateway: CompositionRoot.crop_gateway,
              crop_task_template_gateway: CompositionRoot.crop_task_template_gateway,
              user_lookup: CompositionRoot.user_lookup,
              agricultural_task_gateway: CompositionRoot.agricultural_task_gateway
            )
            interactor.call(input_dto)
          end

          # 中間テーブルの属性を更新
          #
          # @param crop_id [Integer] 作物ID
          # @param id [Integer] 中間テーブル（CropTaskTemplate）のID
          # @param name [String] タスク名（任意）
          # @param time_per_sqm [Float] 単位面積あたりの時間（任意）
          # @param description [String] 説明（任意）
          # @param weather_dependency [String] 天候依存性（任意）
          # @param required_tools [Array<String>] 必要な道具（任意）
          # @param skill_level [String] スキルレベル（任意）
          # @return [Hash] 更新された関連の情報
          # @return [200] 更新成功
          # @return [401] APIキーが無効
          # @return [404] 作物または関連が見つからない
          # @return [422] バリデーションエラー
          def update
            input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateUpdateInput.new(
              user_id: current_user.id,
              crop_id: params[:crop_id],
              template_id: params[:id],
              attributes: template_params.except(:agricultural_task_id).to_h
            )
            presenter = Adapters::Crop::Presenters::CropMastersTaskTemplateUpdateApiPresenter.new(
              view: self,
              translator: CompositionRoot.translator
            )
            interactor = Domain::Crop::Interactors::CropMastersTaskTemplateUpdateInteractor.new(
              output_port: presenter,
              gateway: CompositionRoot.crop_gateway,
              user_lookup: CompositionRoot.user_lookup
            )
            interactor.call(input_dto)
          end

          # 作物から農業タスクの関連を削除
          #
          # @param crop_id [Integer] 作物ID
          # @param id [Integer] 中間テーブル（CropTaskTemplate）のID
          # @return [204] 削除成功
          # @return [401] APIキーが無効
          # @return [404] 作物または関連が見つからない
          def destroy
            input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateDestroyInput.new(
              user_id: current_user.id,
              crop_id: params[:crop_id],
              template_id: params[:id]
            )
            presenter = Adapters::Crop::Presenters::CropMastersTaskTemplateDestroyApiPresenter.new(
              view: self,
              translator: CompositionRoot.translator
            )
            interactor = Domain::Crop::Interactors::CropMastersTaskTemplateDestroyInteractor.new(
              output_port: presenter,
              gateway: CompositionRoot.crop_gateway,
              user_lookup: CompositionRoot.user_lookup
            )
            interactor.call(input_dto)
          end

          private

          def template_params
            params.permit(:agricultural_task_id, :name, :description, :time_per_sqm, :weather_dependency, :skill_level, required_tools: [])
          end
        end
      end
    end
  end
end
