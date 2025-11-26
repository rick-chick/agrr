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
          before_action :set_crop
          before_action :set_template, only: [:update, :destroy]

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
            agricultural_task_id = params[:agricultural_task_id]
            
            unless agricultural_task_id.present?
              render json: { error: 'agricultural_task_id is required' }, status: :unprocessable_entity
              return
            end

            agricultural_task = AgriculturalTask.find_by(id: agricultural_task_id)
            unless agricultural_task
              render json: { error: 'AgriculturalTask not found' }, status: :not_found
              return
            end

            # 権限チェック: 参照タスクまたは自分のタスクのみ関連付け可能
            unless agricultural_task.is_reference || agricultural_task.user_id == current_user.id
              render json: { error: 'You do not have permission to associate this agricultural task' }, status: :forbidden
              return
            end

            # 既に関連付けられているかチェック
            existing_template = @crop.crop_task_templates.find_by(agricultural_task_id: agricultural_task_id)
            if existing_template
              render json: { error: 'AgriculturalTask is already associated with this crop' }, status: :unprocessable_entity
              return
            end

            # 中間テーブルの属性を設定（指定がない場合は農業タスクのデフォルト値を使用）
            template_params = {
              agricultural_task: agricultural_task,
              name: params[:name] || agricultural_task.name,
              description: params[:description] || agricultural_task.description,
              time_per_sqm: params[:time_per_sqm] || agricultural_task.time_per_sqm,
              weather_dependency: params[:weather_dependency] || agricultural_task.weather_dependency,
              required_tools: params[:required_tools] || agricultural_task.required_tools || [],
              skill_level: params[:skill_level] || agricultural_task.skill_level
            }

            template = @crop.crop_task_templates.create!(template_params)
            render json: format_template(template), status: :created
          rescue ActiveRecord::RecordInvalid => e
            render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
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

          private

          def set_crop
            @crop = current_user.crops.where(is_reference: false).find(params[:crop_id])
          rescue ActiveRecord::RecordNotFound
            render json: { error: 'Crop not found' }, status: :not_found
          end

          def set_template
            @template = @crop.crop_task_templates.find(params[:id])
          rescue ActiveRecord::RecordNotFound
            render json: { error: 'AgriculturalTask association not found' }, status: :not_found
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
