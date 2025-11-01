# frozen_string_literal: true

module Api
  module V1
    module Crops
      class CropFertilizeProfilesApiController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :set_crop
        before_action :set_profile, only: [:show, :update, :destroy]

        # GET /api/v1/crops/:crop_id/crop_fertilize_profiles/:id
        def show
          render json: profile_to_json(@profile)
        end

        # POST /api/v1/crops/:crop_id/crop_fertilize_profiles
        def create
          @profile = @crop.crop_fertilize_profiles.build(profile_params)

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

        def set_profile
          @profile = @crop.crop_fertilize_profiles.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: I18n.t('crop_fertilize_profiles.flash.not_found', default: '肥料プロファイルが見つかりません') }, status: :not_found
        end

        def profile_params
          params.require(:crop_fertilize_profile).permit(
            :total_n,
            :total_p,
            :total_k,
            :confidence,
            :notes,
            :sources,
            crop_fertilize_applications_attributes: [
              :id,
              :application_type,
              :count,
              :schedule_hint,
              :total_n,
              :total_p,
              :total_k,
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
      end
    end
  end
end

