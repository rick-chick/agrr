# frozen_string_literal: true

module Crops
  class PestsController < ApplicationController
    before_action :set_crop
    before_action :set_pest, only: [:show, :edit, :update]

    # GET /crops/:crop_id/pests
    def index
      # この作物に関連付けられている害虫を取得（アクセス権限のある害虫のみ）
      # 参照害虫または自分の害虫のみ表示
      @pests = @crop.pests.where("is_reference = ? OR user_id = ?", true, current_user.id).recent
      # 参照害虫も選択可能にするため、利用可能な害虫を取得（管理者も参照害虫と自分の害虫のみ）
      @available_pests = Pest.where("is_reference = ? OR user_id = ?", true, current_user.id).recent
    end

    # GET /crops/:crop_id/pests/:id
    def show
    end

    # GET /crops/:crop_id/pests/new
    def new
      # 既存の害虫を選択する場合
      @pest = Pest.new
      @pest.build_pest_temperature_profile
      @pest.build_pest_thermal_requirement
      @pest.pest_control_methods.build
      
      # この作物にまだ関連付けられていない害虫のリスト（参照害虫または自分の害虫のみ）
      available_pests = Pest.where("is_reference = ? OR user_id = ?", true, current_user.id)
      @unassociated_pests = available_pests.where.not(id: @crop.pest_ids).recent
    end

    # GET /crops/:crop_id/pests/:id/edit
    def edit
      @pest.pest_control_methods.build if @pest.pest_control_methods.empty?
    end

    # POST /crops/:crop_id/pests
    def create
      # 既存の害虫を選択して関連付ける場合
      if params[:pest_id].present?
        existing_pest = Pest.find_by(id: params[:pest_id])
        if existing_pest
          # 既に関連付けられていないかチェック
          unless @crop.pests.include?(existing_pest)
            @crop.pests << existing_pest
            redirect_to crop_pests_path(@crop), notice: I18n.t('crops.pests.flash.associated')
            return
          else
            redirect_to crop_pests_path(@crop), alert: I18n.t('crops.pests.flash.already_associated')
            return
          end
        else
          redirect_to crop_pests_path(@crop), alert: I18n.t('crops.pests.flash.not_found')
          return
        end
      end

      # 新しい害虫を作成する場合
      is_reference = ActiveModel::Type::Boolean.new.cast(pest_params[:is_reference]) || false
      if is_reference && !admin_user?
        return redirect_to crop_pests_path(@crop), alert: I18n.t('crops.pests.flash.reference_only_admin')
      end

      @pest = Pest.new(pest_params)
      unless admin_user?
        @pest.is_reference = false
        @pest.user = current_user
      end

      if @pest.save
        # 作成した害虫を作物に関連付け
        @crop.pests << @pest unless @crop.pests.include?(@pest)
        redirect_to crop_pest_path(@crop, @pest), notice: I18n.t('crops.pests.flash.created')
      else
        available_pests = Pest.where("is_reference = ? OR user_id = ?", true, current_user.id)
        @unassociated_pests = available_pests.where.not(id: @crop.pest_ids).recent
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /crops/:crop_id/pests/:id
    def update
      if pest_params.key?(:is_reference) && !admin_user?
        is_reference = ActiveModel::Type::Boolean.new.cast(pest_params[:is_reference]) || false
        if is_reference != @pest.is_reference
          return redirect_to crop_pest_path(@crop, @pest), alert: I18n.t('crops.pests.flash.reference_flag_admin_only')
        end
      end

      if @pest.update(pest_params)
        redirect_to crop_pest_path(@crop, @pest), notice: I18n.t('crops.pests.flash.updated')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_crop
      @crop = Crop.find(params[:crop_id])
      
      # 作物へのアクセス権限チェック
      # 管理者も参照作物と自身が作成した作物のみアクセス可能
      unless @crop.is_reference || @crop.user_id == current_user.id
        redirect_to crops_path, alert: I18n.t('crops.flash.no_permission')
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to crops_path, alert: I18n.t('crops.flash.not_found')
    end

    def set_pest
      @pest = @crop.pests.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to crop_pests_path(@crop), alert: I18n.t('crops.pests.flash.not_found')
    end

    def pest_params
      params.require(:pest).permit(
        :name,
        :name_scientific,
        :family,
        :order,
        :description,
        :occurrence_season,
        :is_reference,
        pest_temperature_profile_attributes: [
          :id,
          :base_temperature,
          :max_temperature,
          :_destroy
        ],
        pest_thermal_requirement_attributes: [
          :id,
          :required_gdd,
          :first_generation_gdd,
          :_destroy
        ],
        pest_control_methods_attributes: [
          :id,
          :method_type,
          :method_name,
          :description,
          :timing_hint,
          :_destroy
        ]
      )
    end
  end
end

