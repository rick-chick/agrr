# frozen_string_literal: true

class PestsController < ApplicationController
  include DeletionUndoFlow
  before_action :set_pest, only: [:edit, :update, :destroy]

  # GET /pests
  def index
    presenter = Presenters::Html::Pest::PestListHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestListInteractor.new(
      output_port: presenter,
      gateway: pest_gateway,
      user_id: current_user.id
    ).call
  end

  # GET /pests/:id
  def show
    presenter = Presenters::Html::Pest::PestDetailHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestDetailInteractor.new(
      output_port: presenter,
      gateway: pest_gateway,
      user_id: current_user.id
    ).call(params[:id])
  end

  # GET /pests/new
  def new
    @pest = Pest.new
    prepare_crop_selection_for(@pest, selected_ids: normalize_crop_ids_for(@pest, params[:crop_ids]))
    @pest.build_pest_temperature_profile
    @pest.build_pest_thermal_requirement
    @pest.pest_control_methods.build
  end

  # GET /pests/:id/edit
  def edit
    @pest.pest_control_methods.build if @pest.pest_control_methods.empty?
    prepare_crop_selection_for(@pest)
  end

  # POST /pests
  def create
    input_dto = Domain::Pest::Dtos::PestCreateInputDto.from_hash(
      { pest: pest_params.to_h.symbolize_keys, crop_ids: params[:crop_ids] }
    )
    presenter = Presenters::Html::Pest::PestCreateHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestCreateInteractor.new(
      output_port: presenter,
      gateway: pest_gateway,
      user_id: current_user.id
    ).call(input_dto)
  rescue StandardError => e
    if e.message == I18n.t('pests.flash.reference_only_admin')
      redirect_to pests_path, alert: e.message
    else
      @pest = Pest.new(pest_params.to_h.symbolize_keys)
      @pest.valid?
      prepare_crop_selection_for(@pest, selected_ids: normalize_crop_ids_for(@pest, params[:crop_ids]))
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /pests/:id
  def update
    if pest_params.key?(:is_reference) && !current_user.admin?
      requested = ActiveModel::Type::Boolean.new.cast(pest_params[:is_reference])
      if requested != @pest.is_reference
        redirect_to pest_path(@pest), alert: I18n.t('pests.flash.reference_flag_admin_only')
        return
      end
    end

    input_dto = Domain::Pest::Dtos::PestUpdateInputDto.from_hash(
      { pest: pest_params.to_h.symbolize_keys, crop_ids: params[:crop_ids] },
      params[:id]
    )
    presenter = Presenters::Html::Pest::PestUpdateHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestUpdateInteractor.new(
      output_port: presenter,
      gateway: pest_gateway,
      user_id: current_user.id
    ).call(input_dto)
  rescue StandardError => e
    Rails.logger.error "PestsController#update error: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
    @pest.assign_attributes(pest_params.to_h.symbolize_keys)
    @pest.valid?
    prepare_crop_selection_for(@pest)
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_entity
  end

  # DELETE /pests/:id
  def destroy
    respond_to do |format|
      format.html do
        schedule_deletion_with_undo(
          record: @pest,
          toast_message: I18n.t('pests.undo.toast', name: @pest.name),
          fallback_location: pests_path,
          in_use_message_key: 'pests.flash.cannot_delete_in_use',
          delete_error_message_key: 'pests.flash.delete_error'
        )
      rescue Domain::Shared::Policies::PolicyPermissionDenied
        redirect_to pests_path, alert: I18n.t('pests.flash.not_found')
      end

      format.json do
        schedule_deletion_with_undo(
          record: @pest,
          toast_message: I18n.t('pests.undo.toast', name: @pest.name),
          fallback_location: pests_path,
          in_use_message_key: 'pests.flash.cannot_delete_in_use',
          delete_error_message_key: 'pests.flash.delete_error'
        )
      end
    end
  end

  private

  def set_pest
    @pest = Domain::Shared::Policies::PestPolicy.find_editable!(::Pest, current_user, params[:id])
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to pests_path, alert: I18n.t('pests.flash.no_permission')
  rescue ActiveRecord::RecordNotFound
    redirect_to pests_path, alert: I18n.t('pests.flash.not_found')
  end

  def pest_params
    permitted = [
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
    ]

    # 管理者のみ region / pest_id を許可
    permitted << :region if admin_user?
    permitted << :pest_id if admin_user?

    params.require(:pest).permit(*permitted)
  end

  # 害虫と作物を関連付ける（Service経由）
  def associate_crops(pest, crop_ids)
    PestCropAssociationService.associate_crops(pest, crop_ids, user: current_user)
  end

  # 害虫と作物の関連付けを更新（Service経由）
  def update_crop_associations(pest, crop_ids)
    PestCropAssociationService.update_crop_associations(pest, crop_ids, user: current_user)
  end

  def pest_gateway
    @pest_gateway ||= Adapters::Pest::Gateways::PestMemoryGateway.new
  end

  public

  # Presenter から呼ばれるため public
  def render_form(action, status: :ok, locals: {})
    render(action, status: status, locals: locals)
  end

  # Presenter の on_failure から呼ばれるため public
  def normalize_crop_ids_for(pest, raw_ids)
    PestCropAssociationService.normalize_crop_ids(pest, raw_ids, user: current_user)
  end

  def prepare_crop_selection_for(pest, selected_ids: nil)
    @accessible_crops = PestCropAssociationPolicy.accessible_crops_scope(pest, user: current_user).to_a
    allowed_ids = @accessible_crops.map(&:id)
    normalized_selected = Array(selected_ids || pest.crop_ids).map(&:to_i).uniq & allowed_ids

    @selected_crop_ids = normalized_selected
    @crop_cards = @accessible_crops.map do |crop|
      {
        crop: crop,
        selected: normalized_selected.include?(crop.id)
      }
    end
  end

  private
end


