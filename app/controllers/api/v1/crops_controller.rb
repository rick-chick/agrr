# frozen_string_literal: true

require 'open3'
require 'json'

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
          return render json: { error: '作物名を入力してください' }, status: :bad_request
        end

        begin
          # 事前バリデーション: 件数制限をチェック（ダミーCropでバリデーション実行）
          dummy_crop = ::Crop.new(user: current_user, name: 'dummy', is_reference: false)
          # user_resource_limitバリデーションのみチェック（nameバリデーションはスキップ）
          if dummy_crop.valid?
            # valid?がtrueの場合は件数制限なし
          elsif dummy_crop.errors[:base].any?
            # 件数制限エラーを返す
            validation_error = dummy_crop.errors[:base].first
            return render json: { error: validation_error }, status: :unprocessable_entity
          end
          
          # 1. agrrコマンドで作物情報を取得（常に実行して最新情報を取得）
          Rails.logger.info "🤖 [AI Crop] Querying crop info for: #{crop_name}"
          crop_info = fetch_crop_info_from_agrr(crop_name)

          # エラーチェック（エラー時は success: false が返る）
          if crop_info['success'] == false
            error_msg = crop_info['error'] || '作物情報の取得に失敗しました'
            return render json: { error: error_msg }, status: :unprocessable_entity
          end

          # 正常時は crop と stage_requirements がトップレベルに存在
          crop_data = crop_info['crop']
          stage_requirements = crop_info['stage_requirements']
          
          unless crop_data
            return render json: { error: '作物情報が不正な形式です' }, status: :unprocessable_entity
          end
          
          crop_id = crop_data['crop_id']  # agrrが返すcrop_id
          Rails.logger.info "📊 [AI Crop] Retrieved data: crop_id=#{crop_id}, area=#{crop_data['area_per_unit']}, revenue=#{crop_data['revenue_per_area']}, stages=#{stage_requirements&.count || 0}"

          # crop_idで作物を探す（ユーザー作物のみ）
          existing_crop = ::Crop.find_by(id: crop_id, user_id: current_user.id, is_reference: false)
          
          if existing_crop
            # 既存作物が見つかった → 更新
            Rails.logger.info "🔄 [AI Crop] Existing crop found: #{crop_name} (DB_ID: #{existing_crop.id}, is_reference: #{existing_crop.is_reference})"
            Rails.logger.info "🔄 [AI Crop] Updating crop with latest data from agrr"
            
            existing_crop.update!(
              variety: variety.present? ? variety : (crop_data['variety'] || existing_crop.variety),
              area_per_unit: crop_data['area_per_unit'],
              revenue_per_area: crop_data['revenue_per_area'],
              groups: crop_data['groups'] || []
            )
            
            # 既存のステージを削除して新しいステージを保存
            existing_crop.crop_stages.destroy_all
            if stage_requirements.present?
              saved_stages = save_crop_stages(existing_crop.id, stage_requirements)
              Rails.logger.info "🌱 [AI Crop] Updated #{saved_stages} stages for crop##{existing_crop.id}"
            end
            
            return render json: {
              success: true,
              crop_id: existing_crop.id,
              crop_name: existing_crop.name,
              variety: existing_crop.variety,
              area_per_unit: existing_crop.area_per_unit,
              revenue_per_area: existing_crop.revenue_per_area,
              stages_count: stage_requirements&.count || 0,
              is_reference: existing_crop.is_reference,
              message: "作物「#{existing_crop.name}」を最新情報で更新しました"
            }, status: :ok
          end

          # 4. 新規作成（見つからなかった場合）
          Rails.logger.info "🆕 [AI Crop] Creating new crop: #{crop_name} (crop_id: #{crop_id})"
          is_reference = false # AI作成は常にユーザー作物
          user_id = current_user.id

          attrs = {
            user_id: user_id,
            name: crop_name,
            variety: variety || crop_data['variety'],
            area_per_unit: crop_data['area_per_unit'],
            revenue_per_area: crop_data['revenue_per_area'],
            is_reference: is_reference,
            groups: crop_data['groups'] || []
          }

          result = @create_interactor.call(attrs)

          if result.success?
            crop_entity = result.data
            Rails.logger.info "✅ [AI Crop] Created crop##{crop_entity.id}: #{crop_entity.name}"

            # 4. 生育ステージも保存
            if stage_requirements.present?
              saved_stages = save_crop_stages(crop_entity.id, stage_requirements)
              Rails.logger.info "🌱 [AI Crop] Saved #{saved_stages} stages for crop##{crop_entity.id}"
            end

            render json: {
              success: true,
              crop_id: crop_entity.id,
              crop_name: crop_entity.name,
              variety: crop_entity.variety,
              area_per_unit: crop_entity.area_per_unit,
              revenue_per_area: crop_entity.revenue_per_area,
              stages_count: stage_requirements&.count || 0,
              message: "AIで作物「#{crop_entity.name}」の情報を取得して作成しました"
            }, status: :created
          else
            Rails.logger.error "❌ [AI Crop] Failed to create: #{result.error}"
            render json: { error: result.error }, status: :unprocessable_entity
          end

        rescue => e
          Rails.logger.error "❌ [AI Crop] Error: #{e.message}"
          Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
          render json: { error: "作物情報の取得に失敗しました: #{e.message}" }, status: :internal_server_error
        end
      end

      private

      def set_interactors
        gateway = Adapters::Crop::Gateways::CropMemoryGateway.new
        @create_interactor = Domain::Crop::Interactors::CropCreateInteractor.new(gateway)
      end

      def fetch_crop_info_from_agrr(crop_name, max_retries: 3)
        agrr_path = Rails.root.join('lib', 'core', 'agrr').to_s
        command = [
          agrr_path,
          'crop',
          '--query', crop_name,
          '--json'
        ]

        attempt = 0
        last_error = nil

        # リトライループ（ネットワークエラーや一時的なエラーに対応）
        max_retries.times do |retry_count|
          attempt = retry_count + 1
          
          begin
            Rails.logger.debug "🔧 [AGRR Crop Query] #{command.join(' ')} (attempt #{attempt}/#{max_retries})"

            stdout, stderr, status = Open3.capture3(*command)

            # 実行に失敗した場合
            unless status.success?
              error_msg = stderr.strip
              
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
              Rails.logger.error "❌ [AGRR Crop Query Error] Command failed: #{command.join(' ')}"
              Rails.logger.error "   stderr: #{error_msg}"
              raise "Failed to query crop info from agrr: #{error_msg}"
            end

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

      # 生育ステージを保存
      def save_crop_stages(crop_id, stages_data)
        saved_count = 0
        
        stages_data.each do |stage_requirement|
          # stage_requirementの構造: { "stage": {...}, "temperature": {...}, "thermal": {...}, "sunshine": {...} }
          stage_info = stage_requirement['stage']
          
          # CropStageを作成
          stage = ::CropStage.create!(
            crop_id: crop_id,
            name: stage_info['name'],
            order: stage_info['order']
          )
          
          # 温度要件を作成
          if stage_requirement['temperature'].present?
            temp_data = stage_requirement['temperature']
            ::TemperatureRequirement.create!(
              crop_stage_id: stage.id,
              base_temperature: temp_data['base_temperature'],
              optimal_min: temp_data['optimal_min'],
              optimal_max: temp_data['optimal_max'],
              low_stress_threshold: temp_data['low_stress_threshold'],
              high_stress_threshold: temp_data['high_stress_threshold'],
              frost_threshold: temp_data['frost_threshold'],
              sterility_risk_threshold: temp_data['sterility_risk_threshold']
            )
          end
          
          # 日照要件を作成
          if stage_requirement['sunshine'].present?
            sunshine_data = stage_requirement['sunshine']
            ::SunshineRequirement.create!(
              crop_stage_id: stage.id,
              minimum_sunshine_hours: sunshine_data['minimum_sunshine_hours'],
              target_sunshine_hours: sunshine_data['target_sunshine_hours']
            )
          end
          
          # 熱量要件を作成
          if stage_requirement['thermal'].present?
            thermal_data = stage_requirement['thermal']
            ::ThermalRequirement.create!(
              crop_stage_id: stage.id,
              required_gdd: thermal_data['required_gdd']
            )
          end
          
          saved_count += 1
          Rails.logger.debug "  🌱 Stage #{stage.order}: #{stage.name} (ID: #{stage.id})"
        end
        
        saved_count
      rescue => e
        Rails.logger.error "❌ [AI Crop] Failed to save stages: #{e.message}"
        Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
        0
      end
    end
  end
end

