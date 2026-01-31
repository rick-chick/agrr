# frozen_string_literal: true

class PesticidesController < ApplicationController
  include DeletionUndoFlow
  include HtmlCrudResponder
  before_action :set_pesticide, only: [:edit, :update, :destroy]

  # GET /pesticides
  def index
    presenter = Presenters::Html::Pesticide::PesticideListHtmlPresenter.new(view: self)
    Domain::Pesticide::Interactors::PesticideListInteractor.new(
      output_port: presenter,
      gateway: pesticide_gateway,
      user_id: current_user.id
    ).call
  end

  # GET /pesticides/:id
  def show
    presenter = Presenters::Html::Pesticide::PesticideDetailHtmlPresenter.new(view: self)
    Domain::Pesticide::Interactors::PesticideDetailInteractor.new(
      output_port: presenter,
      gateway: pesticide_gateway,
      user_id: current_user.id
    ).call(params[:id])
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to pesticides_path, alert: I18n.t('pesticides.flash.not_found')
  end

  # GET /pesticides/new
  def new
    @pesticide = Pesticide.new
    @pesticide.build_pesticide_usage_constraint
    @pesticide.build_pesticide_application_detail
    load_crops_and_pests
  end

  # GET /pesticides/:id/edit
  def edit
    @pesticide.build_pesticide_usage_constraint unless @pesticide.pesticide_usage_constraint
    @pesticide.build_pesticide_application_detail unless @pesticide.pesticide_application_detail
    load_crops_and_pests
  end

  # POST /pesticides
  def create
    # is_referenceをbooleanに変換してチェック（既存のロジックを維持）
    is_reference = ActiveModel::Type::Boolean.new.cast(pesticide_params[:is_reference]) || false
    if is_reference && !admin_user?
      return redirect_to pesticides_path, alert: I18n.t('pesticides.flash.reference_only_admin')
    end

    input_dto = Domain::Pesticide::Dtos::PesticideCreateInputDto.from_hash(pesticide_params.to_unsafe_h.deep_symbolize_keys)
    presenter = Presenters::Html::Pesticide::PesticideCreateHtmlPresenter.new(view: self)

    # 失敗時にフォーム再表示するために @pesticide をセット
    @pesticide = Pesticide.new(pesticide_params)

    Domain::Pesticide::Interactors::PesticideCreateInteractor.new(
      output_port: presenter,
      gateway: pesticide_gateway,
      user_id: current_user.id
    ).call(input_dto)
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to pesticides_path, alert: I18n.t('pesticides.flash.not_found')
  end

  # PATCH/PUT /pesticides/:id
  def update
    # is_referenceをbooleanに変換してチェック（既存のロジックを維持）
    if pesticide_params.key?(:is_reference)
      is_reference = ActiveModel::Type::Boolean.new.cast(pesticide_params[:is_reference]) || false
      if is_reference != @pesticide.is_reference && !admin_user?
        return redirect_to pesticide_path(@pesticide), alert: I18n.t('pesticides.flash.reference_flag_admin_only')
      end
    end

    input_dto = Domain::Pesticide::Dtos::PesticideUpdateInputDto.from_hash(pesticide_params.to_unsafe_h.deep_symbolize_keys, params[:id])
    presenter = Presenters::Html::Pesticide::PesticideUpdateHtmlPresenter.new(view: self)

    # 失敗時にフォーム再表示するために @pesticide を更新
    @pesticide.assign_attributes(pesticide_params)

    Domain::Pesticide::Interactors::PesticideUpdateInteractor.new(
      output_port: presenter,
      gateway: pesticide_gateway,
      user_id: current_user.id
    ).call(input_dto)
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to pesticides_path, alert: I18n.t('pesticides.flash.not_found')
  end

  # DELETE /pesticides/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Presenters::Html::Pesticide::PesticideDestroyHtmlPresenter.new(view: self)
        Domain::Pesticide::Interactors::PesticideDestroyInteractor.new(
          output_port: presenter,
          gateway: pesticide_gateway,
          user_id: current_user.id
        ).call(params[:id])
      rescue Domain::Shared::Policies::PolicyPermissionDenied
        redirect_to pesticides_path, alert: I18n.t('pesticides.flash.not_found')
      end

      format.json do
        schedule_deletion_with_undo(
          record: @pesticide,
          toast_message: I18n.t('pesticides.undo.toast', name: @pesticide.name),
          fallback_location: pesticides_path,
          in_use_message_key: nil,
          delete_error_message_key: 'pesticides.flash.delete_error'
        )
      rescue Domain::Shared::Policies::PolicyPermissionDenied
        redirect_to pesticides_path, alert: I18n.t('pesticides.flash.not_found')
      end
    end
  end

  # View interface for HTML Presenters（Presenter から呼ばれるため public）
  def render_form(action, status: :ok, locals: {})
    render(action, status: status, locals: locals)
  end

  private

  def set_pesticide
    @pesticide = Domain::Shared::Policies::PesticidePolicy.find_visible!(Pesticide, current_user, params[:id])
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to pesticides_path, alert: I18n.t('pesticides.flash.not_found')
  rescue ActiveRecord::RecordNotFound
    redirect_to pesticides_path, alert: I18n.t('pesticides.flash.not_found')
  end

  def load_crops_and_pests
    # 作物の選択範囲を決定（Policy経由）
    @crops = PesticideAssociationPolicy.accessible_crops_scope(current_user)
    
    # 害虫の選択範囲を決定（Policy経由）
    @pests = PesticideAssociationPolicy.accessible_pests_scope(current_user)
  end

  def pesticide_params
    permitted = [
      :name,
      :active_ingredient,
      :description,
      :crop_id,
      :pest_id,
      :is_reference,
      pesticide_usage_constraint_attributes: [
        :id,
        :min_temperature,
        :max_temperature,
        :max_wind_speed_m_s,
        :max_application_count,
        :harvest_interval_days,
        :other_constraints,
        :_destroy
      ],
      pesticide_application_detail_attributes: [
        :id,
        :dilution_ratio,
        :amount_per_m2,
        :amount_unit,
        :application_method,
        :_destroy
      ]
    ]

    # 管理者のみregionを許可
    permitted << :region if admin_user?

    params.require(:pesticide).permit(*permitted)
  end

  def pesticide_gateway
    @pesticide_gateway ||= Adapters::Pesticide::Gateways::PesticideActiveRecordGateway.new
  end
end

