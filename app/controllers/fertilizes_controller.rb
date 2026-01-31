# frozen_string_literal: true

class FertilizesController < ApplicationController
  include DeletionUndoFlow
  include HtmlCrudResponder
  before_action :set_fertilize, only: [:show, :edit, :update, :destroy]

  # GET /fertilizes
  def index
    presenter = Presenters::Html::Fertilize::FertilizeListHtmlPresenter.new(view: self)
    interactor = Domain::Fertilize::Interactors::FertilizeListInteractor.new(
      output_port: presenter,
      gateway: fertilize_gateway,
      user_id: current_user.id
    )
    interactor.call
  end

  # GET /fertilizes/:id
  def show
    presenter = Presenters::Html::Fertilize::FertilizeDetailHtmlPresenter.new(view: self)
    interactor = Domain::Fertilize::Interactors::FertilizeDetailInteractor.new(
      output_port: presenter,
      gateway: fertilize_gateway,
      user_id: current_user.id
    )
    interactor.call(@fertilize.id)
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.no_permission')
  rescue ActiveRecord::RecordNotFound
    redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.not_found')
  rescue StandardError => e
    redirect_to fertilizes_path, alert: e.message
  end

  # GET /fertilizes/new
  def new
    @fertilize = Fertilize.new
  end

  # GET /fertilizes/:id/edit
  def edit
  end

  # POST /fertilizes
  def create
    if fertilize_params[:is_reference].present? && ActiveModel::Type::Boolean.new.cast(fertilize_params[:is_reference]) && !admin_user?
      redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.reference_only_admin')
      return
    end
    input_dto = Domain::Fertilize::Dtos::FertilizeCreateInputDto.from_hash({ fertilize: fertilize_params.to_h.symbolize_keys })
    presenter = Presenters::Html::Fertilize::FertilizeCreateHtmlPresenter.new(view: self)
    Domain::Fertilize::Interactors::FertilizeCreateInteractor.new(
      output_port: presenter,
      gateway: fertilize_gateway,
      user_id: current_user.id
    ).call(input_dto)
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.no_permission')
  rescue StandardError => e
    @fertilize = Fertilize.new(fertilize_params.to_h.symbolize_keys)
    @fertilize.valid?
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  # PATCH/PUT /fertilizes/:id
  def update
    if fertilize_params[:is_reference].present? && ActiveModel::Type::Boolean.new.cast(fertilize_params[:is_reference]) != @fertilize.is_reference && !admin_user?
      redirect_to fertilize_path(@fertilize), alert: I18n.t('fertilizes.flash.reference_flag_admin_only')
      return
    end
    input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.from_hash({ fertilize: fertilize_params.to_h.symbolize_keys }, params[:id])
    presenter = Presenters::Html::Fertilize::FertilizeUpdateHtmlPresenter.new(view: self)
    Domain::Fertilize::Interactors::FertilizeUpdateInteractor.new(
      output_port: presenter,
      gateway: fertilize_gateway,
      user_id: current_user.id
    ).call(input_dto)
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.no_permission')
  rescue StandardError => e
    @fertilize.assign_attributes(fertilize_params.to_h.symbolize_keys)
    @fertilize.valid?
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_entity
  end

  # DELETE /fertilizes/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Presenters::Html::Fertilize::FertilizeDestroyHtmlPresenter.new(view: self)
        Domain::Fertilize::Interactors::FertilizeDestroyInteractor.new(
          output_port: presenter,
          gateway: fertilize_gateway,
          user_id: current_user.id
        ).call(params[:id])
      rescue Domain::Shared::Policies::PolicyPermissionDenied
        redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.no_permission')
      end

      format.json do
        schedule_deletion_with_undo(
          record: @fertilize,
          toast_message: I18n.t('fertilizes.undo.toast', name: @fertilize.name),
          fallback_location: fertilizes_path,
          in_use_message_key: nil,
          delete_error_message_key: 'fertilizes.flash.delete_error'
        )
      rescue Domain::Shared::Policies::PolicyPermissionDenied
        redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.no_permission')
      end
    end
  end

  private

  def set_fertilize
    @fertilize = Domain::Shared::Policies::FertilizePolicy.find_visible!(Fertilize, current_user, params[:id])
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.no_permission')
  rescue ActiveRecord::RecordNotFound
    redirect_to fertilizes_path, alert: I18n.t('fertilizes.flash.not_found')
  end

  def fertilize_gateway
    Adapters::Fertilize::Gateways::FertilizeActiveRecordGateway.new
  end

  def fertilize_params
    permitted = [
      :name,
      :n,
      :p,
      :k,
      :description,
      :package_size,
      :is_reference
    ]

    # 管理者のみregionを許可
    permitted << :region if admin_user?

    params.require(:fertilize).permit(*permitted)
  end
end

