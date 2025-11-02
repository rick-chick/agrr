# frozen_string_literal: true

require 'open3'
require 'json'

module Api
  module V1
    module Crops
      class CropFertilizeProfilesApiController < Api::V1::BaseController
        # ai_create, ai_updateはHTMLフォームから呼び出すため認証必須
        before_action :authenticate_api_request
        before_action :set_crop, except: [:ai_create]
        before_action :set_crop_for_ai, only: [:ai_create]
        before_action :set_profile, only: [:show, :update, :destroy, :ai_update]

        # GET /api/v1/crops/:crop_id/crop_fertilize_profiles/:id
        def show
          render json: profile_to_json(@profile)
        end

        # POST /api/v1/crops/:crop_id/crop_fertilize_profiles
        def create
          # 既存のプロファイルがある場合は作成不可
          if @crop.crop_fertilize_profile
            return render json: { error: I18n.t('crops.crop_fertilize_profiles.flash.already_exists', default: '既に肥料プロファイルが存在します') }, status: :unprocessable_entity
          end

          @profile = @crop.build_crop_fertilize_profile(profile_params)

          # sourcesをカンマ区切りテキストから配列に変換
          if params.dig(:crop_fertilize_profile, :sources).is_a?(String)
            @profile.sources = params[:crop_fertilize_profile][:sources].split(',').map(&:strip).reject(&:blank?)
          end

          if @profile.save
            render json: profile_to_json(@profile), status: :created
          else
            render json: { error: @profile.errors.full_messages.join(', ') }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/crops/:crop_id/crop_fertilize_profiles/:id
        def update
          # sourcesをカンマ区切りテキストから配列に変換
          if params.dig(:crop_fertilize_profile, :sources).is_a?(String)
            @profile.sources = params[:crop_fertilize_profile][:sources].split(',').map(&:strip).reject(&:blank?)
          end

          if @profile.update(profile_params)
            render json: profile_to_json(@profile)
          else
            render json: { error: @profile.errors.full_messages.join(', ') }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/crops/:crop_id/crop_fertilize_profiles/:id
        def destroy
          @profile.destroy
          head :no_content
        rescue StandardError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        # POST /api/v1/crops/:crop_id/crop_fertilize_profiles/ai_create
        # AIで肥料プロファイルを取得して新規作成（登録時は常に新規作成）
        def ai_create
          unless @crop
            return render json: { error: I18n.t('crops.flash.not_found', default: '作物が見つかりません') }, status: :not_found
          end

          begin
            # agrrコマンドで肥料プロファイル情報を取得
            Rails.logger.info "🤖 [AI Fertilize Profile] Querying profile for crop: #{@crop.name} (ID: #{@crop.id})"
            profile_info = fetch_profile_info_from_agrr(@crop.id)

            # エラーチェック
            if profile_info['success'] == false
              error_msg = profile_info['error'] || I18n.t('api.errors.crop_fertilize_profiles.fetch_failed', default: '肥料プロファイルの取得に失敗しました')
              return render json: { error: error_msg }, status: :unprocessable_entity
            end

            profile_data = profile_info['profile']
            unless profile_data
              return render json: { error: I18n.t('api.errors.crop_fertilize_profiles.invalid_payload', default: '無効なデータ形式です') }, status: :unprocessable_entity
            end

            Rails.logger.info "📊 [AI Fertilize Profile] Retrieved profile data for crop##{@crop.id}"

            # 既存のプロファイルがある場合は更新、なければ新規作成
            if @crop.crop_fertilize_profile
              profile = @crop.crop_fertilize_profile
              Rails.logger.info "🔄 [AI Fertilize Profile] Updating existing profile##{profile.id} for crop##{@crop.id}"
              
              # 既存のapplicationsを削除
              profile.crop_fertilize_applications.destroy_all
              
              # プロファイルを更新
              profile.update!(
                sources: profile_data['sources'] || [],
                confidence: profile_data['confidence'] || 0.5,
                notes: profile_data['notes']
              )
              
              # applicationsを作成
              if profile_data['applications'].present?
                profile_data['applications'].each do |app_data|
                  profile.crop_fertilize_applications.create!(
                    application_type: app_data['type'],
                    count: app_data['count'] || 1,
                    schedule_hint: app_data['schedule_hint'],
                    per_application_n: app_data.dig('per_application', 'N'),
                    per_application_p: app_data.dig('per_application', 'P'),
                    per_application_k: app_data.dig('per_application', 'K')
                  )
                end
              end
              
              profile.reload
              Rails.logger.info "✅ [AI Fertilize Profile] Updated profile##{profile.id} for crop##{@crop.id}"
              
              render json: {
                success: true,
                profile_id: profile.id,
                crop_id: @crop.id,
                crop_name: @crop.name,
                total_n: profile.total_n,
                total_p: profile.total_p,
                total_k: profile.total_k,
                confidence: profile.confidence,
                applications_count: profile.crop_fertilize_applications.count,
                message: I18n.t('api.messages.crop_fertilize_profiles.updated_by_ai', default: '肥料プロファイルを更新しました', crop_name: @crop.name)
              }, status: :ok
            else
              Rails.logger.info "🆕 [AI Fertilize Profile] Creating new profile for crop##{@crop.id}"
              profile = CropFertilizeProfile.from_agrr_output(crop: @crop, profile_data: profile_data)
              Rails.logger.info "✅ [AI Fertilize Profile] Created profile##{profile.id} for crop##{@crop.id}"

              render json: {
                success: true,
                profile_id: profile.id,
                crop_id: @crop.id,
                crop_name: @crop.name,
                total_n: profile.total_n,
                total_p: profile.total_p,
                total_k: profile.total_k,
                confidence: profile.confidence,
                applications_count: profile.crop_fertilize_applications.count,
                message: I18n.t('api.messages.crop_fertilize_profiles.created_by_ai', default: '肥料プロファイルを作成しました', crop_name: @crop.name)
              }, status: :created
            end

          rescue => e
            Rails.logger.error "❌ [AI Fertilize Profile] Error: #{e.message}"
            Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
            render json: { error: I18n.t('api.errors.crop_fertilize_profiles.fetch_failed_with_reason', default: '取得に失敗しました', message: e.message) }, status: :internal_server_error
          end
        end

        # POST /api/v1/crops/:crop_id/crop_fertilize_profiles/:id/ai_update
        # AIで肥料プロファイルを取得して更新
        def ai_update
          begin
            # agrrコマンドで肥料プロファイル情報を取得
            Rails.logger.info "🤖 [AI Fertilize Profile] Querying profile for update: crop=#{@crop.name} (ID: #{@crop.id}), profile=#{@profile.id}"
            profile_info = fetch_profile_info_from_agrr(@crop.id)

            # エラーチェック
            if profile_info['success'] == false
              error_msg = profile_info['error'] || I18n.t('api.errors.crop_fertilize_profiles.fetch_failed', default: '肥料プロファイルの取得に失敗しました')
              return render json: { error: error_msg }, status: :unprocessable_entity
            end

            profile_data = profile_info['profile']
            unless profile_data
              return render json: { error: I18n.t('api.errors.crop_fertilize_profiles.invalid_payload', default: '無効なデータ形式です') }, status: :unprocessable_entity
            end

            Rails.logger.info "🔄 [AI Fertilize Profile] Updating profile##{@profile.id} with latest data from agrr"

            # 既存のapplicationsを削除
            @profile.crop_fertilize_applications.destroy_all

            # プロファイルを更新
            @profile.update!(
              sources: profile_data['sources'] || [],
              confidence: profile_data['confidence'] || 0.5,
              notes: profile_data['notes']
            )

            # applicationsを作成
            if profile_data['applications'].present?
              profile_data['applications'].each do |app_data|
                @profile.crop_fertilize_applications.create!(
                  application_type: app_data['type'],
                  count: app_data['count'] || 1,
                  schedule_hint: app_data['schedule_hint'],
                  per_application_n: app_data.dig('per_application', 'N'),
                  per_application_p: app_data.dig('per_application', 'P'),
                  per_application_k: app_data.dig('per_application', 'K')
                )
              end
            end

            @profile.reload
            Rails.logger.info "✅ [AI Fertilize Profile] Updated profile##{@profile.id} for crop##{@crop.id}"

            render json: {
              success: true,
              profile_id: @profile.id,
              crop_id: @crop.id,
              crop_name: @crop.name,
              total_n: @profile.total_n,
              total_p: @profile.total_p,
              total_k: @profile.total_k,
              confidence: @profile.confidence,
              applications_count: @profile.crop_fertilize_applications.count,
              message: I18n.t('api.messages.crop_fertilize_profiles.updated_by_ai', default: '肥料プロファイルを更新しました', crop_name: @crop.name)
            }, status: :ok

          rescue => e
            Rails.logger.error "❌ [AI Fertilize Profile] Error: #{e.message}"
            Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
            render json: { error: I18n.t('api.errors.crop_fertilize_profiles.fetch_failed_with_reason', default: '取得に失敗しました', message: e.message) }, status: :internal_server_error
          end
        end

        private

        def set_crop
          @crop = Crop.find(params[:crop_id])
          
          # 権限チェック
          unless @crop.is_reference || @crop.user_id == current_user.id || current_user.admin?
            render json: { error: I18n.t('crops.flash.no_permission', default: 'この作物にアクセスする権限がありません') }, status: :forbidden
            return false
          end
        rescue ActiveRecord::RecordNotFound
          render json: { error: I18n.t('crops.flash.not_found', default: '作物が見つかりません') }, status: :not_found
          return false
        end

        def set_crop_for_ai
          # ai_createはHTMLフォームから呼び出すため認証済みユーザーが使用
          @crop = Crop.find(params[:crop_id])
          
          # 権限チェック（参照作物は誰でも閲覧可能、ユーザー作物は所有者のみ）
          unless @crop.is_reference || @crop.user_id == current_user.id || current_user.admin?
            render json: { error: I18n.t('crops.flash.no_permission', default: 'この作物にアクセスする権限がありません') }, status: :forbidden
            return false
          end
        rescue ActiveRecord::RecordNotFound
          render json: { error: I18n.t('crops.flash.not_found', default: '作物が見つかりません') }, status: :not_found
          return false
        end

        def set_profile
          # 1:1の関係なので、crop_idから直接取得（params[:id]は使用しないが、ルーティング互換性のため残す）
          @profile = @crop.crop_fertilize_profile
          unless @profile
            render json: { error: I18n.t('crops.crop_fertilize_profiles.flash.not_found', default: '肥料プロファイルが見つかりません') }, status: :not_found
          end
        end

        def profile_params
          params.require(:crop_fertilize_profile).permit(
            :confidence,
            :notes,
            :sources,
            crop_fertilize_applications_attributes: [
              :id,
              :application_type,
              :count,
              :schedule_hint,
              :per_application_n,
              :per_application_p,
              :per_application_k,
              :_destroy
            ]
          )
        end

        def profile_to_json(profile)
          {
            id: profile.id,
            crop_id: profile.crop_id,
            total_n: profile.total_n,
            total_p: profile.total_p,
            total_k: profile.total_k,
            sources: profile.sources || [],
            confidence: profile.confidence,
            notes: profile.notes,
            applications: profile.crop_fertilize_applications.order(:application_type, :id).map do |app|
              {
                id: app.id,
                application_type: app.application_type,
                count: app.count,
                schedule_hint: app.schedule_hint,
                nutrients: {
                  n: app.total_n,
                  p: app.total_p,
                  k: app.total_k
                },
                per_application: app.per_application_n.present? || app.per_application_p.present? || app.per_application_k.present? ? {
                  n: app.per_application_n,
                  p: app.per_application_p,
                  k: app.per_application_k
                } : nil,
                created_at: app.created_at,
                updated_at: app.updated_at
              }
            end,
            created_at: profile.created_at,
            updated_at: profile.updated_at
          }
        end

        def fetch_profile_info_from_agrr(crop_id, max_retries: 3)
          attempt = 0
          last_error = nil

          max_retries.times do |retry_count|
            attempt = retry_count + 1

            begin
              Rails.logger.debug "🔧 [AGRR Fertilize Profile Query] fertilize profile --crop-id #{crop_id} --json (attempt #{attempt}/#{max_retries})"

              client_path = Rails.root.join('bin', 'agrr_client').to_s
              stdout, stderr, status = Open3.capture3(client_path, 'fertilize', 'profile', '--crop-id', crop_id.to_s, '--json')

              unless status.success?
                error_msg = stderr.strip

                # デーモンが起動していない場合
                if error_msg.include?('FileNotFoundError') ||
                   error_msg.include?('No such file or directory') ||
                   error_msg.include?('SOCKET_PATH')
                  Rails.logger.error "❌ [AGRR Fertilize Profile Query] Daemon not running: #{error_msg}"
                  return {
                    'success' => false,
                    'error' => I18n.t('api.errors.crop_fertilize_profiles.daemon_not_running', default: 'AGRRサービスが起動していません。サービスを起動してから再度お試しください。'),
                    'code' => 'daemon_not_running'
                  }
                end

                # 一時的なエラーの場合はリトライ
                if error_msg.include?('decompressing') ||
                   error_msg.include?('Connection') ||
                   error_msg.include?('timeout') ||
                   error_msg.include?('Network')
                  Rails.logger.warn "⚠️  [AGRR Fertilize Profile Query] Transient error (attempt #{attempt}/#{max_retries}): #{error_msg}"

                  if attempt < max_retries
                    sleep_time = 2 ** attempt
                    Rails.logger.info "⏳ [AGRR Fertilize Profile Query] Retrying in #{sleep_time} seconds..."
                    sleep(sleep_time)
                    next
                  end
                end

                Rails.logger.error "❌ [AGRR Fertilize Profile Query Error] Command failed: fertilize profile --crop-id #{crop_id} --json"
                Rails.logger.error "   stderr: #{error_msg}"
                raise "Failed to query fertilize profile from agrr: #{error_msg}"
              end

              Rails.logger.debug "📥 [AGRR Fertilize Profile Output] #{stdout[0..500]}#{'...' if stdout.length > 500}"

              parsed_data = JSON.parse(stdout)

              if parsed_data['success'] == false
                Rails.logger.error "📊 [AGRR Fertilize Profile Error] #{parsed_data['error']} (code: #{parsed_data['code']})"
              else
                profile_data = parsed_data['profile'] || parsed_data
                Rails.logger.debug "📊 [AGRR Fertilize Profile Data] totals: N=#{profile_data&.dig('totals', 'N')}, P=#{profile_data&.dig('totals', 'P')}, K=#{profile_data&.dig('totals', 'K')}"

                if attempt > 1
                  Rails.logger.info "✅ [AGRR Fertilize Profile Query] Succeeded after #{attempt} attempts"
                end

                # profileキーがない場合は、profileキーでラップした形式に変換
                parsed_data = { 'profile' => profile_data, 'success' => true } unless parsed_data['profile']
              end

              return parsed_data

            rescue JSON::ParserError => e
              Rails.logger.error "❌ [AGRR Fertilize Profile Query] JSON parse error: #{e.message}"
              raise "Invalid JSON response from agrr: #{e.message}"

            rescue => e
              last_error = e
              Rails.logger.warn "⚠️  [AGRR Fertilize Profile Query] Unexpected error (attempt #{attempt}/#{max_retries}): #{e.message}"

              if attempt < max_retries
                sleep_time = 2 ** attempt
                Rails.logger.info "⏳ [AGRR Fertilize Profile Query] Retrying in #{sleep_time} seconds..."
                sleep(sleep_time)
                next
              end

              raise
            end
          end

          if last_error
            raise last_error
          else
            raise "Failed to query fertilize profile after #{max_retries} attempts"
          end
        end
      end
    end
  end
end

