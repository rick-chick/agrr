# frozen_string_literal: true

require "open3"
require "json"

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

        begin
          # 1. agrrコマンドで害虫情報を取得
          Rails.logger.info "🤖 [AI Pest] Querying pest info for: #{pest_name}"
          pest_info = fetch_pest_info_from_agrr(pest_name, affected_crops)

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
          existing_pest = ::Pest.find_by(
            name: pest_data["name"],
            is_reference: false,
            user_id: current_user.id
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
              pest_record = ::Pest.find(pest_entity.id)
              associate_crops_from_api(pest_record, chosen_affected_crops)
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

        rescue => e
          Rails.logger.error "❌ [AI Pest] Error: #{e.message}"
          Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
          render json: { error: I18n.t("api.errors.pests.fetch_failed_with_reason", message: e.message, default: "害虫情報の取得に失敗しました: %{message}") }, status: :internal_server_error
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

        begin
          # agrrコマンドで害虫情報を取得
          Rails.logger.info "🤖 [AI Pest] Querying pest info for update: #{pest_name} (ID: #{@pest.id})"
          affected_crops = [] # 更新時は影響作物は指定しない
          pest_info = fetch_pest_info_from_agrr(pest_name, affected_crops)

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

        rescue => e
          Rails.logger.error "❌ [AI Pest] Error: #{e.message}"
          Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
          render json: { error: I18n.t("api.errors.pests.fetch_failed_with_reason", message: e.message, default: "害虫情報の取得に失敗しました: %{message}") }, status: :internal_server_error
        end
      end

      private

      def set_pest
        presenter = Presenters::Api::Pest::PestLoadForAiUpdatePresenter.new(view: self)
        Domain::Pest::Interactors::PestLoadAuthorizedModelForEditInteractor.new(output_port: presenter,
          user_id: current_user.id, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
      end

      def set_interactors
        @create_interactor = Adapters::Pest::PestCreateForAiAdapter.new(user_id: current_user.id)
        @update_interactor = Adapters::Pest::PestUpdateForAiAdapter.new(user_id: current_user.id)
      end

      def fetch_pest_info_from_agrr(pest_name, affected_crops = [], max_retries: 3)
        agrr_service = AgrrService.new

        attempt = 0
        last_error = nil

        # リトライループ
        max_retries.times do |retry_count|
          attempt = retry_count + 1

          begin
            # 影響作物をJSON配列に変換
            crops_json = affected_crops.to_json
            Rails.logger.debug "🔧 [AGRR Pest-to-Crop Query] pest-to-crop --pest #{pest_name} --crops #{crops_json} (attempt #{attempt}/#{max_retries})"

            # AgrrServiceを使ってpest_to_cropコマンドを実行
            stdout = agrr_service.pest_to_crop(pest: pest_name, crops: crops_json, language: "ja")

            # agrrコマンドの生の出力をログに記録
            Rails.logger.debug "📥 [AGRR Pest-to-Crop Output] #{stdout[0..500]}#{'...' if stdout.length > 500}"

            parsed_data = JSON.parse(stdout)

            # データ構造を検証
            if parsed_data["success"] == false
              Rails.logger.error "📊 [AGRR Pest-to-Crop Error] #{parsed_data['error']} (code: #{parsed_data['code']})"
            else
              pest_data = parsed_data["data"]&.dig("pest")
              Rails.logger.debug "📊 [AGRR Pest-to-Crop Data] name: #{pest_data&.dig('name')}"
              Rails.logger.debug "📊 [AGRR Pest-to-Crop Data] family: #{pest_data&.dig('family')}"

              if attempt > 1
                Rails.logger.info "✅ [AGRR Pest-to-Crop Query] Succeeded after #{attempt} attempts"
              end
            end

            return parsed_data

          rescue AgrrService::DaemonNotRunningError => e
            Rails.logger.error "❌ [AGRR Pest-to-Crop Query] Daemon not running: #{e.message}"
            return {
              "success" => false,
              "error" => I18n.t("api.errors.pests.daemon_not_running", default: "AGRRサービスが起動していません。サービスを起動してから再度お試しください。"),
              "code" => "daemon_not_running"
            }
          rescue AgrrService::CommandExecutionError => e
            error_msg = e.message

            # 一時的なエラーの場合はリトライ
            if error_msg.include?("decompressing") ||
               error_msg.include?("Connection") ||
               error_msg.include?("timeout") ||
               error_msg.include?("Network")

              Rails.logger.warn "⚠️  [AGRR Pest-to-Crop Query] Transient error (attempt #{attempt}/#{max_retries}): #{error_msg}"

              if attempt < max_retries
                sleep_time = 2 ** attempt
                Rails.logger.info "⏳ [AGRR Pest-to-Crop Query] Retrying in #{sleep_time} seconds..."
                sleep(sleep_time)
                next
              end
            end

            Rails.logger.error "❌ [AGRR Pest-to-Crop Query Error] Command failed: #{error_msg}"
            raise "Failed to query pest info from agrr: #{error_msg}"
          rescue JSON::ParserError => e
            Rails.logger.error "❌ [AGRR Pest-to-Crop Query] JSON parse error: #{e.message}"
            raise "Invalid JSON response from agrr: #{e.message}"

          rescue => e
            last_error = e
            Rails.logger.warn "⚠️  [AGRR Pest-to-Crop Query] Unexpected error (attempt #{attempt}/#{max_retries}): #{e.message}"

            if attempt < max_retries
              sleep_time = 2 ** attempt
              Rails.logger.info "⏳ [AGRR Pest-to-Crop Query] Retrying in #{sleep_time} seconds..."
              sleep(sleep_time)
              next
            end

            raise
          end
        end

        # 最大リトライ回数を超えた場合
        if last_error
          raise last_error
        else
          raise "Failed to query pest info after #{max_retries} attempts"
        end
      end

      def associate_crops_from_api(pest, affected_crops)
        Rails.logger.info "🔗 [AI Pest] associate_crops_from_api called with: #{affected_crops.inspect}"

        # affected_cropsは [{"crop_id": "1", "crop_name": "ブロッコリー"}, ...] の形式
        # ハッシュまたはシンボルキーのハッシュの両方に対応
        crop_ids = affected_crops.map do |c|
          # ハッシュの場合（文字列キーまたはシンボルキー）
          if c.is_a?(Hash)
            c["crop_id"] || c[:crop_id] || c["crop_id".to_sym] || c[:'crop_id']
          # ActionController::Parametersの場合はハッシュのように扱える
          elsif c.respond_to?(:[])
            c["crop_id"] || c[:crop_id] || c["crop_id".to_sym]
          # オブジェクトの場合
          elsif c.respond_to?(:crop_id)
            c.crop_id
          else
            nil
          end
        end.compact.reject(&:blank?).map(&:to_i)

        Rails.logger.info "🔗 [AI Pest] Extracted crop IDs: #{crop_ids.inspect}"
        Rails.logger.info "🔗 [AI Pest] Current user: #{current_user&.id || 'nil'}, is_admin?: #{admin_user?}"

        # フォールバック: crop_id が空の場合、crop_name からIDを引当て
        if crop_ids.empty?
          crop_names = affected_crops.map do |c|
            if c.is_a?(Hash)
              c["crop_name"] || c[:crop_name] || c["crop_name".to_sym] || c[:'crop_name']
            elsif c.respond_to?(:[])
              c["crop_name"] || c[:crop_name] || c["crop_name".to_sym]
            elsif c.respond_to?(:crop_name)
              c.crop_name
            else
              nil
            end
          end.compact.reject(&:blank?).map(&:to_s)

          Rails.logger.info "🔗 [AI Pest] Fallback with crop names: #{crop_names.inspect}"

          crop_names.each do |name|
            # 参照作物を優先して一致させる（なければユーザー作物も考慮）
            candidate = ::Crop.reference.find_by(name: name)
            candidate ||= if current_user
              ::Crop.user_owned.where(user_id: current_user.id).find_by(name: name)
            else
              nil
            end

            if candidate
              crop_ids << candidate.id
              Rails.logger.info "✅ [AI Pest] Fallback matched crop by name: #{name} -> ID=#{candidate.id}"
            else
              Rails.logger.warn "⚠️  [AI Pest] Could not match crop by name: #{name}"
            end
          end

          crop_ids.uniq!
          Rails.logger.info "🔗 [AI Pest] Crop IDs after fallback: #{crop_ids.inspect}"
        end

        if crop_ids.empty?
          Rails.logger.warn "⚠️  [AI Pest] No crop IDs extracted from affected_crops"
          return
        end

        associated_count = 0
        crop_ids.each do |crop_id|
          crop = ::Crop.find_by(id: crop_id)
          unless crop
            Rails.logger.warn "⚠️  [AI Pest] Crop not found: ID=#{crop_id}"
            next
          end

          Rails.logger.info "🔗 [AI Pest] Processing crop: #{crop.name} (ID: #{crop.id}, is_reference: #{crop.is_reference}, user_id: #{crop.user_id})"

          # 権限チェック：参照作物は常にアクセス可能（AI API特有のロジック）
          # ユーザー作物の場合はPolicy経由で関連付け可否を判定
          can_access = if crop.is_reference
            # 参照作物は誰でもアクセス可能（AI API特有のロジック）
            true
          elsif current_user.nil? || current_user.anonymous?
            # アノニマスユーザーの場合、ユーザー作物は許可しない（セキュリティのため）
            false
          else
            # Policy経由で関連付け可否を判定
            PestCropAssociationPolicy.crop_accessible_for_pest?(crop, pest, user: current_user)
          end

          Rails.logger.info "🔗 [AI Pest] Can access crop #{crop.name}? #{can_access}"

          if can_access
            if pest.crops.include?(crop)
              Rails.logger.info "ℹ️  [AI Pest] Crop already associated: #{crop.name}"
            else
              pest.crops << crop
              associated_count += 1
              Rails.logger.info "✅ [AI Pest] Associated crop: #{crop.name} (ID: #{crop.id})"
            end
          else
            Rails.logger.warn "⚠️  [AI Pest] Cannot access crop: #{crop.name} (user_id: #{crop.user_id}, current_user: #{current_user&.id})"
          end
        end

        Rails.logger.info "✅ [AI Pest] Crop association completed: #{associated_count} crops associated"
      rescue => e
        Rails.logger.error "❌ [AI Pest] Failed to associate crops: #{e.message}"
        Rails.logger.error "❌ [AI Pest] Backtrace: #{e.backtrace.first(5).join("\n")}"
        # 関連付けエラーは致命的ではないため、ログ出力のみ
      end
    end
  end
end
