# frozen_string_literal: true

module Api
  module V1
    class PestsController < Api::V1::BaseController
      # ai_createは認証不要（無料プラン機能の一部）
      # ai_updateはHTMLフォームから呼び出すため認証必須
      skip_before_action :authenticate_api_request, only: [ :ai_create ]
      before_action :authenticate_api_request, only: [ :ai_update ]
      before_action :set_interactors, only: [ :ai_create, :ai_update ]
      before_action :set_pest, only: [ :ai_update ]

      # POST /api/v1/pests/ai_create
      # AIで害虫情報を取得して保存
      def ai_create
        pest_name = params[:name]&.strip

        if current_user.anonymous?
          return render json: { error: I18n.t("auth.api.login_required") }, status: :unauthorized
        end

        # affected_cropsを適切に処理（ActionController::Parametersまたは配列に対応）
        affected_crops_raw = params[:affected_crops] || []
        affected_crops = if affected_crops_raw.is_a?(Array)
          affected_crops_raw.map do |c|
            case c
            when ActionController::Parameters
              c.permit(:crop_id, :crop_name).to_h
            when Hash
              c.symbolize_keys
            else
              c.to_h if c.respond_to?(:to_h)
            end
          end.compact
        else
          []
        end

        # デバッグ: 受け取ったパラメータをログに記録
        Rails.logger.info "🔍 [AI Pest] Received params: name=#{pest_name}"
        Rails.logger.info "🔍 [AI Pest] affected_crops_raw class: #{affected_crops_raw.class}, is_array?: #{affected_crops_raw.is_a?(Array)}"
        Rails.logger.info "🔍 [AI Pest] affected_crops (processed): #{affected_crops.inspect}"
        Rails.logger.info "🔍 [AI Pest] affected_crops count: #{affected_crops.count}"

        unless pest_name.present?
          return render json: { error: I18n.t("api.errors.pests.name_required", default: "害虫名を入力してください") }, status: :bad_request
        end

        # 1. agrrコマンドで害虫情報を取得
        Rails.logger.info "🤖 [AI Pest] Querying pest info for: #{pest_name}"
        pest_info = CompositionRoot.pest_ai_daemon_query_gateway.fetch_pest_json(pest_name, affected_crops)
        if pest_info["error_response"]
          return render json: { error: pest_info["message"] }, status: pest_info["http_status"]
        end

        # エラーチェック
        if pest_info["success"] == false
          error_msg = pest_info["error"] || I18n.t("api.errors.pests.fetch_failed", default: "害虫情報の取得に失敗しました")
          status_code = pest_info["code"] == "daemon_not_running" ? :service_unavailable : :unprocessable_entity
          return render json: { error: error_msg }, status: status_code
        end

        # 正常時は pest がトップレベルに存在
        pest_data = pest_info["data"]&.dig("pest")

        unless pest_data
          return render json: { error: I18n.t("api.errors.pests.invalid_payload", default: "不正なデータ形式です") }, status: :unprocessable_entity
        end

        affected_crops_from_agrr = pest_info.dig("data", "affected_crops")
        if affected_crops_from_agrr.present? && !affected_crops_from_agrr.is_a?(Array)
          message = I18n.t(
            "api.errors.pests.invalid_affected_crops",
            default: "agrr応答のaffected_cropsが不正です"
          )
          Rails.logger.error "❌ [AI Pest] Invalid affected_crops format: #{affected_crops_from_agrr.inspect}"
          return render json: { error: message }, status: :unprocessable_entity
        end

        Rails.logger.info "📊 [AI Pest] Retrieved data: name=#{pest_data['name']}, family=#{pest_data['family']}"

        # 2. 既存の害虫を検索（AI作成は常にユーザー害虫）
        existing_pest = CompositionRoot.pest_gateway.find_user_owned_non_reference_pest_record_by_name(
          user_id: current_user.id,
          name: pest_data["name"]
        )

        # 3. pest_dataを整形（所有者・参照フラグは Policy に委譲）
        base_attrs = {
          name: pest_data["name"],
          name_scientific: pest_data["name_scientific"],
          family: pest_data["family"],
          order: pest_data["order"],
          description: pest_data["description"],
          occurrence_season: pest_data["occurrence_season"],
          temperature_profile: pest_data["temperature_profile"],
          thermal_requirement: pest_data["thermal_requirement"],
          control_methods: pest_data["control_methods"] || []
        }

        if existing_pest
          # 既存の害虫を更新（所有者・参照フラグは変更しない）
          Rails.logger.info "🔄 [AI Pest] Updating existing pest##{existing_pest.id}: #{pest_data['name']}"
          result = @update_interactor.call(existing_pest.id, base_attrs)
          status_code = :ok
        else
          # 新規作成（所有者・参照フラグの決定は Policy に委譲）
          Rails.logger.info "🆕 [AI Pest] Creating new pest: #{pest_data['name']}"

          # 所有者・参照フラグの決定のみ Policy（正規化）から取得
          normalized = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_create(current_user, {})

          attrs_for_create = base_attrs.merge(
            user_id: normalized[:user_id],
            is_reference: normalized[:is_reference]
          )

          result = @create_interactor.call(attrs_for_create.symbolize_keys)
          status_code = :created
        end

        if result.success?
          pest_entity = result.data
          action = existing_pest ? "Updated" : "Created"
          Rails.logger.info "✅ [AI Pest] #{action} pest##{pest_entity.id}: #{pest_entity.name}"

          # 4. 害虫と作物を関連付ける（affected_cropsから）
          Rails.logger.info "🔗 [AI Pest] Before association check: affected_crops.present?=#{affected_crops.present?}, is_a?(Array)=#{affected_crops.is_a?(Array)}"

          # agrr応答のaffected_cropsを優先し、無ければUIからのaffected_cropsにフォールバック
          chosen_affected_crops = if affected_crops_from_agrr.is_a?(Array) && affected_crops_from_agrr.any?
            Rails.logger.info "🔗 [AI Pest] Using affected_crops from agrr response: #{affected_crops_from_agrr.inspect}"
            affected_crops_from_agrr
          else
            Rails.logger.info "🔗 [AI Pest] Using affected_crops from UI params: #{affected_crops.inspect}"
            affected_crops
          end

          if chosen_affected_crops.present? && chosen_affected_crops.is_a?(Array)
            Rails.logger.info "🔗 [AI Pest] Starting crop association for pest##{pest_entity.id} (count=#{chosen_affected_crops.size})"
            CompositionRoot.pest_gateway.associate_affected_crops_for_ai_pest(
              pest_id: pest_entity.id,
              affected_crops: chosen_affected_crops,
              user: current_user,
              logger: CompositionRoot.logger
            )
          else
            Rails.logger.warn "⚠️  [AI Pest] Skipping crop association: affected_crops is empty or not an array"
          end

          render json: {
            success: true,
            pest_id: pest_entity.id,
            pest_name: pest_entity.name,
            name_scientific: pest_entity.name_scientific,
            family: pest_entity.family,
            order: pest_entity.order,
            description: pest_entity.description,
            occurrence_season: pest_entity.occurrence_season,
            message: I18n.t("api.messages.pests.created_by_ai", name: pest_entity.name, default: "害虫「%{name}」の情報を取得して保存しました")
          }, status: status_code
        else
          Rails.logger.error "❌ [AI Pest] Failed to #{existing_pest ? 'update' : 'create'}: #{result.error}"
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/pests/:id/ai_update
      # AIで害虫情報を取得して更新（編集時は既存を編集）
      def ai_update
        pest_name = params[:name]&.strip

        unless pest_name.present?
          return render json: { error: I18n.t("api.errors.pests.name_required", default: "害虫名を入力してください") }, status: :bad_request
        end

        unless @pest
          return render json: { error: I18n.t("api.errors.pests.not_found", default: "害虫が見つかりません") }, status: :not_found
        end

        # agrrコマンドで害虫情報を取得
        Rails.logger.info "🤖 [AI Pest] Querying pest info for update: #{pest_name} (ID: #{@pest.id})"
        affected_crops = [] # 更新時は影響作物は指定しない
        pest_info = CompositionRoot.pest_ai_daemon_query_gateway.fetch_pest_json(pest_name, affected_crops)
        if pest_info["error_response"]
          return render json: { error: pest_info["message"] }, status: pest_info["http_status"]
        end

        # エラーチェック
        if pest_info["success"] == false
          error_msg = pest_info["error"] || I18n.t("api.errors.pests.fetch_failed", default: "害虫情報の取得に失敗しました")
          status_code = pest_info["code"] == "daemon_not_running" ? :service_unavailable : :unprocessable_entity
          return render json: { error: error_msg }, status: status_code
        end

        pest_data = pest_info["data"]&.dig("pest")
        unless pest_data
          return render json: { error: I18n.t("api.errors.pests.invalid_payload", default: "不正なデータ形式です") }, status: :unprocessable_entity
        end

        Rails.logger.info "🔄 [AI Pest] Updating pest##{@pest.id} with latest data from agrr"

        # pest_dataを整形
        attrs = {
          name: pest_data["name"],
          name_scientific: pest_data["name_scientific"],
          family: pest_data["family"],
          order: pest_data["order"],
          description: pest_data["description"],
          occurrence_season: pest_data["occurrence_season"],
          temperature_profile: pest_data["temperature_profile"],
          thermal_requirement: pest_data["thermal_requirement"],
          control_methods: pest_data["control_methods"] || []
        }

        result = @update_interactor.call(@pest.id, attrs.symbolize_keys)

        if result.success?
          pest_entity = result.data
          Rails.logger.info "✅ [AI Pest] Updated pest##{pest_entity.id}: #{pest_entity.name}"

          render json: {
            success: true,
            pest_id: pest_entity.id,
            pest_name: pest_entity.name,
            name_scientific: pest_entity.name_scientific,
            family: pest_entity.family,
            order: pest_entity.order,
            description: pest_entity.description,
            occurrence_season: pest_entity.occurrence_season,
            is_reference: pest_entity.is_reference,
            message: I18n.t("api.messages.pests.updated_by_ai", name: pest_entity.name, default: "害虫「%{name}」を更新しました")
          }, status: :ok
        else
          Rails.logger.error "❌ [AI Pest] Failed to update: #{result.error}"
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end

      private

      def set_pest
        presenter = Presenters::Api::Pest::PestLoadForAiUpdatePresenter.new(view: self)
        Domain::Pest::Interactors::PestLoadAuthorizedModelForEditInteractor.new(output_port: presenter,
          user_id: current_user.id, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
      end

      def set_interactors
        pair = CompositionRoot.pest_ai_interactors_for(user_id: current_user.id)
        @create_interactor = pair.create_interactor
        @update_interactor = pair.update_interactor
      end

    end
  end
end
