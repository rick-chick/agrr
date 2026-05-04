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
          before_action :set_crop, only: [ :index ]
          before_action :set_crop_and_template, only: [ :update, :destroy ]

          # 作物に紐づく農業タスク一覧を取得
          #
          # @param crop_id [Integer] 作物ID
          # @return [Array<Hash>] 作物に紐づく農業タスクの配列（中間テーブルの属性も含む）
          # @return [200] 成功
          # @return [401] APIキーが無効
          # @return [404] 作物が見つからない
          def index
            @templates = @crop.crop_task_templates.includes(:agricultural_task)
            render json: @templates.map { |template| format_template(template) }
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
            input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInputDto.new(
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
            presenter = Presenters::Api::Crop::CropMastersTaskTemplateCreatePresenter.new(
              view: self,
              translator: CompositionRoot.translator
            )
            interactor = Domain::Crop::Interactors::CropMastersTaskTemplateCreateInteractor.new(
              output_port: presenter,
              gateway: CompositionRoot.crop_gateway,
              user_lookup: CompositionRoot.user_lookup
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
            update_params = template_params.except(:agricultural_task_id)

            if @template.update(update_params)
              render json: format_template(@template.reload)
            else
              render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
            end
          end

          # 作物から農業タスクの関連を削除
          #
          # @param crop_id [Integer] 作物ID
          # @param id [Integer] 中間テーブル（CropTaskTemplate）のID
          # @return [204] 削除成功
          # @return [401] APIキーが無効
          # @return [404] 作物または関連が見つからない
          def destroy
            @template.destroy!
            head :no_content
          end

          def render_response(json:, status:)
            render json: json, status: status
          end

          private

          def set_crop
            presenter = Presenters::Api::Crop::CropLoadForMastersPresenter.new(view: self)
            interactor = Domain::Crop::Interactors::CropLoadUserNonReferenceForMastersInteractor.new(output_port: presenter,
              user_id: current_user.id, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup)
            interactor.call(params[:crop_id])
          end

          def set_crop_and_template
            failure = Presenters::Api::Crop::CropNestedRecordNotFoundJsonPresenter.new(
              view: self,
              error_message: "AgriculturalTask association not found"
            )
            interactor = Domain::Crop::Interactors::CropLoadMastersAuthorizedCropTaskTemplateInteractor.new(
              failure_presenter: failure,
              user_id: current_user.id,
              gateway: CompositionRoot.crop_gateway,
              user_lookup: CompositionRoot.user_lookup
            )
            bundle = interactor.call(params[:crop_id], params[:id])
            return if bundle.nil?

            @crop = bundle.persisted_crop
            @template = bundle.persisted_crop_task_template
          end

          def template_params
            params.permit(:agricultural_task_id, :name, :description, :time_per_sqm, :weather_dependency, :skill_level, required_tools: [])
          end

          def format_template(template)
            {
              id: template.id,
              crop_id: template.crop_id,
              agricultural_task_id: template.agricultural_task_id,
              name: template.name,
              description: template.description,
              time_per_sqm: template.time_per_sqm,
              weather_dependency: template.weather_dependency,
              required_tools: template.required_tools || [],
              skill_level: template.skill_level,
              agricultural_task: template.agricultural_task ? {
                id: template.agricultural_task.id,
                name: template.agricultural_task.name,
                description: template.agricultural_task.description,
                is_reference: template.agricultural_task.is_reference
              } : nil,
              created_at: template.created_at,
              updated_at: template.updated_at
            }
          end
        end
      end
    end
  end
end
