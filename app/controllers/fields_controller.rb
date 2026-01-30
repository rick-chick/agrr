# frozen_string_literal: true

class FieldsController < ApplicationController
  before_action :set_farm
  before_action :set_field, only: [:show, :edit, :update, :destroy]

  # GET /farms/:farm_id/fields
  def index
    presenter = Presenters::Html::Field::FieldListHtmlPresenter.new(view: self, farm: @farm)
    interactor = Domain::Field::Interactors::FieldListInteractor.new(
      output_port: presenter,
      gateway: field_gateway,
      user_id: current_user.id
    )
    interactor.call(@farm.id)
  end

  # GET /fields/:id
  def show
    presenter = Presenters::Html::Field::FieldDetailHtmlPresenter.new(view: self, farm: @farm)
    interactor = Domain::Field::Interactors::FieldDetailInteractor.new(
      output_port: presenter,
      gateway: field_gateway,
      user_id: current_user.id
    )
    interactor.call(params[:id])
  end

  # GET /farms/:farm_id/fields/new
  def new
    @field = @farm.fields.build
  end

  # GET /farms/:farm_id/fields/:id/edit
  def edit
    # Field is already loaded by set_field
  end

  # POST /farms/:farm_id/fields
  def create
    input_dto = Domain::Field::Dtos::FieldCreateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys)
    presenter = Presenters::Html::Field::FieldCreateHtmlPresenter.new(view: self)
    interactor = Domain::Field::Interactors::FieldCreateInteractor.new(
      output_port: presenter,
      gateway: field_gateway,
      user_id: current_user.id
    )
    interactor.call(input_dto, @farm.id)
  end

  # PATCH/PUT /farms/:farm_id/fields/:id
  def update
    input_dto = Domain::Field::Dtos::FieldUpdateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id])
    presenter = Presenters::Html::Field::FieldUpdateHtmlPresenter.new(view: self)
    interactor = Domain::Field::Interactors::FieldUpdateInteractor.new(
      output_port: presenter,
      gateway: field_gateway,
      user_id: current_user.id
    )
    interactor.call(input_dto)
  end

  # DELETE /farms/:farm_id/fields/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Presenters::Html::Field::FieldDestroyHtmlPresenter.new(view: self)
        interactor = Domain::Field::Interactors::FieldDestroyInteractor.new(
          output_port: presenter,
          gateway: field_gateway,
          user_id: current_user.id
        )
        interactor.call(params[:id])
      end
      format.json do
        presenter = Presenters::Api::Field::FieldDeletePresenter.new(view: self)
        interactor = Domain::Field::Interactors::FieldDestroyInteractor.new(
          output_port: presenter,
          gateway: field_gateway,
          user_id: current_user.id
        )
        interactor.call(params[:id])
      end
    end
  end

  # FieldDeletePresenter (format.json) が参照する View インターフェース
  def render_response(json:, status:)
    render json: json, status: status
  end

  def undo_deletion_path(undo_token:)
    Rails.application.routes.url_helpers.undo_deletion_path(undo_token: undo_token)
  end

  private

  def set_farm
    if admin_user?
      # Admin can access any farm
      @farm = Farm.find(params[:farm_id])
    else
      # Regular users can only access their own farms
      @farm = Domain::Shared::Policies::FarmPolicy.find_owned!(Farm, current_user, params[:farm_id])
    end
  rescue PolicyPermissionDenied, ActiveRecord::RecordNotFound
    redirect_to farms_path, alert: I18n.t('fields.flash.farm_not_found')
  end

  def set_field
    @field = @farm.fields.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to url_for(controller: 'fields', action: 'index', farm_id: @farm.id), alert: I18n.t('fields.flash.not_found')
  end

  def field_gateway
    Adapters::Field::Gateways::FieldActiveRecordGateway.new
  end
end
