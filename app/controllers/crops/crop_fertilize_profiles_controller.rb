# frozen_string_literal: true

module Crops
  class CropFertilizeProfilesController < ApplicationController
    before_action :set_crop
    before_action :set_profile, only: [:show, :edit, :update, :destroy]

    # GET /crops/:crop_id/crop_fertilize_profiles/:id
    def show
    end

    # GET /crops/:crop_id/crop_fertilize_profiles/new
    def new
      # 既存のプロファイルがある場合は編集画面にリダイレクト
      if @crop.crop_fertilize_profile
        redirect_to edit_crop_crop_fertilize_profile_path(@crop, @crop.crop_fertilize_profile)
        return
      end
      @profile = @crop.build_crop_fertilize_profile
    end

    # GET /crops/:crop_id/crop_fertilize_profiles/:id/edit
    def edit
    end

    # POST /crops/:crop_id/crop_fertilize_profiles
    def create
      # 既存のプロファイルがある場合は作成不可
      if @crop.crop_fertilize_profile
        redirect_to crop_path(@crop), alert: I18n.t('crops.crop_fertilize_profiles.flash.already_exists', default: '既に肥料プロファイルが存在します')
        return
      end

      @profile = @crop.build_crop_fertilize_profile(profile_params)

      # sourcesをカンマ区切りテキストから配列に変換
      if params.dig(:crop_fertilize_profile, :sources).is_a?(String)
        @profile.sources = params[:crop_fertilize_profile][:sources].split(',').map(&:strip).reject(&:blank?)
      end

      if @profile.save
        redirect_to crop_path(@crop), notice: I18n.t('crops.crop_fertilize_profiles.flash.created', default: '肥料プロファイルを作成しました')
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /crops/:crop_id/crop_fertilize_profiles/:id
    def update
      # sourcesをカンマ区切りテキストから配列に変換
      if params.dig(:crop_fertilize_profile, :sources).is_a?(String)
        @profile.sources = params[:crop_fertilize_profile][:sources].split(',').map(&:strip).reject(&:blank?)
      end

      if @profile.update(profile_params)
        redirect_to crop_path(@crop), notice: I18n.t('crops.crop_fertilize_profiles.flash.updated', default: '肥料プロファイルを更新しました')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /crops/:crop_id/crop_fertilize_profiles/:id
    def destroy
      @profile.destroy
      redirect_to crop_path(@crop), notice: I18n.t('crops.crop_fertilize_profiles.flash.destroyed', default: '肥料プロファイルを削除しました')
    rescue StandardError => e
      redirect_to crop_path(@crop), alert: I18n.t('crops.crop_fertilize_profiles.flash.delete_error', default: '削除に失敗しました', message: e.message)
    end

    private

    def set_crop
      @crop = Crop.find(params[:crop_id])
      
      # 参照作物の場合は誰でも閲覧可能、ユーザー作物の場合は所有者のみ
      unless @crop.is_reference || @crop.user_id == current_user.id || admin_user?
        redirect_to crops_path, alert: I18n.t('crops.flash.no_permission', default: 'この作物にアクセスする権限がありません')
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to crops_path, alert: I18n.t('crops.flash.not_found', default: '作物が見つかりません')
    end

    def set_profile
      # 1:1の関係なので、crop_idから直接取得（params[:id]は使用しないが、ルーティング互換性のため残す）
      @profile = @crop.crop_fertilize_profile
      unless @profile
        redirect_to crop_path(@crop), alert: I18n.t('crops.crop_fertilize_profiles.flash.not_found', default: '肥料プロファイルが見つかりません')
      end
    end

    def profile_params
      params.require(:crop_fertilize_profile).permit(
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
  end
end

