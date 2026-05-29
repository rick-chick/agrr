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

        # GET /api/v1/masters/crops
        def index
          presenter = Adapters::Crop::Presenters::CropListApiPresenter.new(view: self)
          interactor = Domain::Crop::Interactors::CropListInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup)
          interactor.call
        end

        # GET /api/v1/masters/crops/:id
        def show
          input_valid?(:show) || return
          presenter = Adapters::Crop::Presenters::CropDetailApiPresenter.new(view: self)
          interactor = Domain::Crop::Interactors::CropDetailInteractor.new(output_port: presenter,
            user_id: current_user.id,
            show_detail_read_gateway: CompositionRoot.crop_show_detail_read_gateway,
            user_lookup: CompositionRoot.user_lookup)
          interactor.call(params[:id])
        end

        # POST /api/v1/masters/crops
        def create
          input_dto = Domain::Crop::Dtos::CropCreateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys)
          unless valid_crop_params?(input_dto)
            render_response(json: { errors: [ "name is required" ] }, status: :unprocessable_entity)
            return
          end
          presenter = Adapters::Crop::Presenters::CropCreateApiPresenter.new(view: self)
          interactor = Domain::Crop::Interactors::CropCreateInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.crop_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup)
          interactor.call(input_dto)
        end

        # PATCH/PUT /api/v1/masters/crops/:id
        def update
          input_dto = Domain::Crop::Dtos::CropUpdateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id].to_i)
          presenter = Adapters::Crop::Presenters::CropUpdateApiPresenter.new(view: self)
          interactor = Domain::Crop::Interactors::CropUpdateInteractor.new(output_port: presenter,
            user_id: current_user.id, gateway: CompositionRoot.crop_gateway, translator: translator, user_lookup: CompositionRoot.user_lookup)
          interactor.call(input_dto)
        end

        # DELETE /api/v1/masters/crops/:id
        def destroy
          input_valid?(:destroy) || return
          presenter = Adapters::Crop::Presenters::CropDeleteApiPresenter.new(view: self)
          interactor = Domain::Crop::Interactors::CropDestroyInteractor.new(output_port: presenter,
            user_id: current_user.id,
            translator: translator, gateway: CompositionRoot.crop_gateway, user_lookup: CompositionRoot.user_lookup)
          interactor.call(params[:id])
        end

        # CropDeleteView: undo 用 JSON の undo_path 組み立て
        def undo_deletion_path(undo_token:)
          Rails.application.routes.url_helpers.undo_deletion_path(undo_token: undo_token)
        end

        private


        def input_valid?(action)
          case action
          when :show, :destroy
            return true if params[:id].present?
            render_response(json: { error: "Crop not found" }, status: :not_found)
            false
          else
            true
          end
        end

        def valid_crop_params?(input_dto)
          input_dto.name.present?
        end

      end
    end
  end
end
