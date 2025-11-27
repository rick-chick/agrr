# frozen_string_literal: true

module Api
  module V1
    class CropsController < Api::V1::BaseController
      # ai_createは認証不要（無料プラン機能の一部）
      skip_before_action :authenticate_api_request, only: [:ai_create]
      before_action :set_interactors, only: [:ai_create]

      # POST /api/v1/crops/ai_create
      # AIで作物情報を取得して保存
      def ai_create
        crop_name = params[:name]&.strip
        variety = params[:variety]&.strip

        unless crop_name.present?
          return render json: { error: I18n.t('api.errors.crops.name_required') }, status: :bad_request
        end

        begin
          # AGRR から作物情報を取得（テストではこのメソッドを差し替えて固定レスポンスを返す）
          crop_info = fetch_crop_info_from_agrr(crop_name)

          service = CropAiUpsertService.new(
            user: current_user,
            create_interactor: @create_interactor
          )

          result = service.call(crop_name: crop_name, variety: variety, crop_info: crop_info)
          render json: result.body, status: result.status
        rescue => e
          Rails.logger.error "❌ [AI Crop] Error: #{e.message}"
          Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
          render json: { error: I18n.t('api.errors.crops.fetch_failed_with_reason', message: e.message) }, status: :internal_server_error
        end
      end

      private

      def set_interactors
        gateway = Adapters::Crop::Gateways::CropMemoryGateway.new
        @create_interactor = Domain::Crop::Interactors::CropCreateInteractor.new(gateway)
      end

      def fetch_crop_info_from_agrr(crop_name, max_retries: 3)
        agrr_service = AgrrService.new
        
        attempt = 0
        last_error = nil

        # リトライループ（ネットワークエラーや一時的なエラーに対応）
        max_retries.times do |retry_count|
          attempt = retry_count + 1
          
          begin
            Rails.logger.debug "🔧 [AGRR Crop Query] crop --query #{crop_name} --json (attempt #{attempt}/#{max_retries})"

            stdout = agrr_service.crop(query: crop_name, json: true)

            # agrrコマンドの生の出力をログに記録（最初の500文字のみ）
            Rails.logger.debug "📥 [AGRR Crop Output] #{stdout[0..500]}#{'...' if stdout.length > 500}"

            parsed_data = JSON.parse(stdout)

            # データ構造を検証
            if parsed_data['success'] == false
              # エラーレスポンスの場合
              Rails.logger.error "📊 [AGRR Crop Error] #{parsed_data['error']} (code: #{parsed_data['code']})"
            else
              # 正常レスポンスの場合
              crop_data = parsed_data['crop']
              stage_requirements = parsed_data['stage_requirements']
              Rails.logger.debug "📊 [AGRR Crop Data] crop_id: #{crop_data&.dig('crop_id')}"
              Rails.logger.debug "📊 [AGRR Crop Data] name: #{crop_data&.dig('name')}"
              Rails.logger.debug "📊 [AGRR Crop Data] area_per_unit: #{crop_data&.dig('area_per_unit')}"
              Rails.logger.debug "📊 [AGRR Crop Data] revenue_per_area: #{crop_data&.dig('revenue_per_area')}"
              Rails.logger.debug "📊 [AGRR Crop Data] stages_count: #{stage_requirements&.count || 0}"
              
              if attempt > 1
                Rails.logger.info "✅ [AGRR Crop Query] Succeeded after #{attempt} attempts"
              end
            end

            return parsed_data

          rescue AgrrService::DaemonNotRunningError => e
            # Daemonが起動していない場合はリトライしない
            Rails.logger.error "❌ [AGRR Crop Query] Daemon not running: #{e.message}"
            raise "AGRR daemon is not running: #{e.message}"
          rescue AgrrService::CommandExecutionError => e
            # コマンド実行エラー
            error_msg = e.message
            
            # 一時的なネットワークエラーや圧縮エラーの場合はリトライ
            if error_msg.include?('decompressing') || 
               error_msg.include?('Connection') || 
               error_msg.include?('timeout') ||
               error_msg.include?('Network')
              
              Rails.logger.warn "⚠️  [AGRR Crop Query] Transient error (attempt #{attempt}/#{max_retries}): #{error_msg}"
              
              # リトライ前に指数バックオフで待機
              if attempt < max_retries
                sleep_time = 2 ** attempt # 2秒、4秒、8秒...
                Rails.logger.info "⏳ [AGRR Crop Query] Retrying in #{sleep_time} seconds..."
                sleep(sleep_time)
                next
              end
            end
            
            # リトライしないエラー、または最終試行での失敗
            Rails.logger.error "❌ [AGRR Crop Query Error] Command failed: #{error_msg}"
            raise "Failed to query crop info from agrr: #{error_msg}"
          rescue JSON::ParserError => e
            # JSONパースエラー（リトライしても意味がない）
            Rails.logger.error "❌ [AGRR Crop Query] JSON parse error: #{e.message}"
            raise "Invalid JSON response from agrr: #{e.message}"
            
          rescue => e
            # その他の予期しないエラー
            last_error = e
            Rails.logger.warn "⚠️  [AGRR Crop Query] Unexpected error (attempt #{attempt}/#{max_retries}): #{e.message}"
            
            if attempt < max_retries
              sleep_time = 2 ** attempt
              Rails.logger.info "⏳ [AGRR Crop Query] Retrying in #{sleep_time} seconds..."
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
          raise "Failed to query crop info after #{max_retries} attempts"
        end
      end
    end
  end
end
