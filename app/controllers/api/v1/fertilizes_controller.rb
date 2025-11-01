# frozen_string_literal: true

require 'open3'
require 'json'

module Api
  module V1
    class FertilizesController < Api::V1::BaseController
      # ai_createは認証不要（無料プラン機能の一部）
      skip_before_action :authenticate_api_request, only: [:ai_create]
      before_action :set_interactors, only: [:ai_create]

      # POST /api/v1/fertilizes/ai_create
      # AIで肥料情報を取得して保存
      def ai_create
        fertilize_name = params[:name]&.strip

        unless fertilize_name.present?
          return render json: { error: I18n.t('api.errors.fertilizes.name_required') }, status: :bad_request
        end

        begin
          # 1. agrrコマンドで肥料情報を取得（常に実行して最新情報を取得）
          Rails.logger.info "🤖 [AI Fertilize] Querying fertilize info for: #{fertilize_name}"
          fertilize_info = fetch_fertilize_info_from_agrr(fertilize_name)

          # エラーチェック（エラー時は success: false が返る）
          if fertilize_info['success'] == false
            error_msg = fertilize_info['error'] || I18n.t('api.errors.fertilizes.fetch_failed')
            # デーモン未起動の場合は特別なステータスコードを使用
            status_code = fertilize_info['code'] == 'daemon_not_running' ? :service_unavailable : :unprocessable_entity
            return render json: { error: error_msg }, status: status_code
          end

          # 正常時は fertilize がトップレベルに存在
          fertilize_data = fertilize_info['fertilize']
          
          unless fertilize_data
            return render json: { error: I18n.t('api.errors.fertilizes.invalid_payload') }, status: :unprocessable_entity
          end
          
          # agrrの結果に基づいて、name（商品名）とpackage_sizeを使用
          # nameはagrrから返された商品名をそのまま使用
          fertilize_name_from_agrr = fertilize_data['name']
          fertilize_package_size_from_agrr = fertilize_data['package_size']
          
          Rails.logger.info "📊 [AI Fertilize] Retrieved data: name=#{fertilize_name_from_agrr}, n=#{fertilize_data['n']}, p=#{fertilize_data['p']}, k=#{fertilize_data['k']}, package_size=#{fertilize_package_size_from_agrr}"

          # name（商品名）で肥料を探す（ユーザー肥料のみ）
          # agrrから返された商品名を使用
          existing_fertilize = ::Fertilize.find_by(name: fertilize_name_from_agrr, is_reference: false)

          if existing_fertilize
            # 既存肥料が見つかった → 更新
            Rails.logger.info "🔄 [AI Fertilize] Existing fertilize found: #{fertilize_name} (DB_ID: #{existing_fertilize.id}, is_reference: #{existing_fertilize.is_reference})"
            Rails.logger.info "🔄 [AI Fertilize] Updating fertilize with latest data from agrr"
            
            # agrrから返された商品名とpackage_sizeを使用して更新
            attrs = {
              name: fertilize_name_from_agrr,  # agrrから返された商品名
              n: fertilize_data['n'],
              p: fertilize_data['p'],
              k: fertilize_data['k'],
              description: fertilize_data['description'],
              package_size: fertilize_package_size_from_agrr  # agrrから返されたpackage_size
            }
            
            result = @update_interactor.call(existing_fertilize.id, attrs)

            if result.success?
              fertilize_entity = result.data
              Rails.logger.info "✅ [AI Fertilize] Updated fertilize##{fertilize_entity.id}: #{fertilize_entity.name}"
              
              return render json: {
                success: true,
                fertilize_id: fertilize_entity.id,
                fertilize_name: fertilize_entity.name,
                n: fertilize_entity.n,
                p: fertilize_entity.p,
                k: fertilize_entity.k,
                description: fertilize_entity.description,
                package_size: fertilize_entity.package_size,
                is_reference: fertilize_entity.is_reference,
                message: I18n.t('api.messages.fertilizes.updated_with_latest', name: fertilize_entity.name)
              }, status: :ok
            else
              Rails.logger.error "❌ [AI Fertilize] Failed to update: #{result.error}"
              return render json: { error: result.error }, status: :unprocessable_entity
            end
          end

          # 新規作成（見つからなかった場合）
          Rails.logger.info "🆕 [AI Fertilize] Creating new fertilize: #{fertilize_name}"
          is_reference = false # AI作成は常にユーザー肥料

          # agrrから返された商品名とpackage_sizeを使用して新規作成
          attrs = {
            name: fertilize_name_from_agrr,  # agrrから返された商品名
            n: fertilize_data['n'],
            p: fertilize_data['p'],
            k: fertilize_data['k'],
            description: fertilize_data['description'],
            package_size: fertilize_package_size_from_agrr,  # agrrから返されたpackage_size
            is_reference: is_reference
          }

          result = @create_interactor.call(attrs)

          if result.success?
            fertilize_entity = result.data
            Rails.logger.info "✅ [AI Fertilize] Created fertilize##{fertilize_entity.id}: #{fertilize_entity.name}"

            render json: {
              success: true,
              fertilize_id: fertilize_entity.id,
              fertilize_name: fertilize_entity.name,
              n: fertilize_entity.n,
              p: fertilize_entity.p,
              k: fertilize_entity.k,
              description: fertilize_entity.description,
              package_size: fertilize_entity.package_size,
              message: I18n.t('api.messages.fertilizes.created_by_ai', name: fertilize_entity.name)
            }, status: :created
          else
            Rails.logger.error "❌ [AI Fertilize] Failed to create: #{result.error}"
            render json: { error: result.error }, status: :unprocessable_entity
          end

        rescue => e
          Rails.logger.error "❌ [AI Fertilize] Error: #{e.message}"
          Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
          render json: { error: I18n.t('api.errors.fertilizes.fetch_failed_with_reason', message: e.message) }, status: :internal_server_error
        end
      end

      private

      def set_interactors
        gateway = Adapters::Fertilize::Gateways::FertilizeMemoryGateway.new
        @create_interactor = Domain::Fertilize::Interactors::FertilizeCreateInteractor.new(gateway)
        @update_interactor = Domain::Fertilize::Interactors::FertilizeUpdateInteractor.new(gateway)
      end

      def fetch_fertilize_info_from_agrr(fertilize_name, max_retries: 3)
        # AgrrServiceにfertilizeメソッドがない場合、直接コマンドを実行する必要がある
        # ただし、base_gateway_v2にはfertilizeコマンドの処理がないため、
        # 一時的にagrr_client経由で実行する
        agrr_service = AgrrService.new
        
        attempt = 0
        last_error = nil

        # リトライループ（ネットワークエラーや一時的なエラーに対応）
        max_retries.times do |retry_count|
          attempt = retry_count + 1
          
          begin
            Rails.logger.debug "🔧 [AGRR Fertilize Query] fertilize get --name #{fertilize_name} --json (attempt #{attempt}/#{max_retries})"

            # AgrrServiceにはfertilizeメソッドがないため、直接コマンドを実行
            # TODO: AgrrServiceにfertilizeメソッドを追加するか、base_gateway_v2で処理する
            client_path = Rails.root.join('bin', 'agrr_client').to_s
            stdout, stderr, status = Open3.capture3(client_path, 'fertilize', 'get', '--name', fertilize_name, '--json')

            # 実行に失敗した場合
            unless status.success?
              error_msg = stderr.strip
              
              # デーモンが起動していない場合（FileNotFoundError: No such file or directory）
              if error_msg.include?('FileNotFoundError') || 
                 error_msg.include?('No such file or directory') ||
                 error_msg.include?('SOCKET_PATH')
                
                Rails.logger.error "❌ [AGRR Fertilize Query] Daemon not running: #{error_msg}"
                return {
                  'success' => false,
                  'error' => I18n.t('api.errors.fertilizes.daemon_not_running', default: 'AGRRサービスが起動していません。サービスを起動してから再度お試しください。'),
                  'code' => 'daemon_not_running'
                }
              end
              
              # 一時的なネットワークエラーや圧縮エラーの場合はリトライ
              if error_msg.include?('decompressing') || 
                 error_msg.include?('Connection') || 
                 error_msg.include?('timeout') ||
                 error_msg.include?('Network')
                
                Rails.logger.warn "⚠️  [AGRR Fertilize Query] Transient error (attempt #{attempt}/#{max_retries}): #{error_msg}"
                
                # リトライ前に指数バックオフで待機
                if attempt < max_retries
                  sleep_time = 2 ** attempt # 2秒、4秒、8秒...
                  Rails.logger.info "⏳ [AGRR Fertilize Query] Retrying in #{sleep_time} seconds..."
                  sleep(sleep_time)
                  next
                end
              end
              
              # リトライしないエラー、または最終試行での失敗
              Rails.logger.error "❌ [AGRR Fertilize Query Error] Command failed: fertilize get --name #{fertilize_name} --json"
              Rails.logger.error "   stderr: #{error_msg}"
              raise "Failed to query fertilize info from agrr: #{error_msg}"
            end

            # agrrコマンドの生の出力をログに記録（最初の500文字のみ）
            Rails.logger.debug "📥 [AGRR Fertilize Output] #{stdout[0..500]}#{'...' if stdout.length > 500}"

            parsed_data = JSON.parse(stdout)

            # データ構造を検証
            if parsed_data['success'] == false
              # エラーレスポンスの場合
              Rails.logger.error "📊 [AGRR Fertilize Error] #{parsed_data['error']} (code: #{parsed_data['code']})"
            else
              # agrrの出力形式に応じてデータを取得
              # 形式1: {"fertilize": {...}} (期待される形式)
              # 形式2: {"name": "...", "npk": "46-0-0", ...} (実際の形式)
              fertilize_data = parsed_data['fertilize'] || parsed_data
              
              # npk文字列がある場合はパースしてn, p, kに変換
              if fertilize_data['npk'] && !fertilize_data['n']
                npk_values = fertilize_data['npk'].split('-').map { |v| v.to_f }
                fertilize_data['n'] = npk_values[0] if npk_values[0] && npk_values[0] > 0
                fertilize_data['p'] = npk_values[1] if npk_values[1] && npk_values[1] > 0
                fertilize_data['k'] = npk_values[2] if npk_values[2] && npk_values[2] > 0
              end
              
              Rails.logger.debug "📊 [AGRR Fertilize Data] name: #{fertilize_data&.dig('name')}"
              Rails.logger.debug "📊 [AGRR Fertilize Data] n: #{fertilize_data&.dig('n')}, p: #{fertilize_data&.dig('p')}, k: #{fertilize_data&.dig('k')}"
              Rails.logger.debug "📊 [AGRR Fertilize Data] package_size: #{fertilize_data&.dig('package_size')}"
              
              if attempt > 1
                Rails.logger.info "✅ [AGRR Fertilize Query] Succeeded after #{attempt} attempts"
              end
              
              # fertilizeキーがない場合は、fertilizeキーでラップした形式に変換
              parsed_data = { 'fertilize' => fertilize_data, 'success' => true } unless parsed_data['fertilize']
            end

            return parsed_data

          rescue JSON::ParserError => e
            # JSONパースエラー（リトライしても意味がない）
            Rails.logger.error "❌ [AGRR Fertilize Query] JSON parse error: #{e.message}"
            raise "Invalid JSON response from agrr: #{e.message}"
            
          rescue => e
            # その他の予期しないエラー
            last_error = e
            Rails.logger.warn "⚠️  [AGRR Fertilize Query] Unexpected error (attempt #{attempt}/#{max_retries}): #{e.message}"
            
            if attempt < max_retries
              sleep_time = 2 ** attempt
              Rails.logger.info "⏳ [AGRR Fertilize Query] Retrying in #{sleep_time} seconds..."
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
          raise "Failed to query fertilize info after #{max_retries} attempts"
        end
      end
    end
  end
end

