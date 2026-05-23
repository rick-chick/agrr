# frozen_string_literal: true

class FieldsController < ApplicationController
  before_action :set_farm, except: [ :index ]
  before_action :set_field, only: [ :edit, :update, :destroy ]

  # GET /farms/:farm_id/fields
  def index
    presenter = Adapters::Field::Presenters::FieldListHtmlPresenter.new(view: self)
    interactor = Domain::Field::Interactors::FieldListInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.field_gateway, user_lookup: CompositionRoot.user_lookup)
    interactor.call(params[:farm_id])
  end

  # GET /farms/:farm_id/fields/:id
  def show
    presenter = Adapters::Field::Presenters::FieldDetailHtmlPresenter.new(view: self)
    interactor = Domain::Field::Interactors::FieldDetailInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.field_gateway, user_lookup: CompositionRoot.user_lookup)
    interactor.call(params[:id])
  end

  # GET /farms/:farm_id/fields/new
  def new
    presenter = Adapters::Field::Presenters::FieldNewMasterFormHtmlPresenter.new(view: self)
    Domain::Field::Interactors::FieldNewMasterFormInteractor.new(output_port: presenter,
      user_id: current_user.id, farm_id: @farm.id, gateway: CompositionRoot.field_gateway, user_lookup: CompositionRoot.user_lookup).call
  end

  # GET /farms/:farm_id/fields/:id/edit
  def edit
    # Field is already loaded by set_field
  end

  # POST /farms/:farm_id/fields
  def create
    input_dto = Domain::Field::Dtos::FieldCreateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys)
    presenter = Adapters::Field::Presenters::FieldCreateHtmlPresenter.new(view: self)
    interactor = Domain::Field::Interactors::FieldCreateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.field_gateway, user_lookup: CompositionRoot.user_lookup)
    interactor.call(input_dto, @farm.id)
  end

  # PATCH/PUT /farms/:farm_id/fields/:id
  def update
    input_dto = Domain::Field::Dtos::FieldUpdateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id])
    presenter = Adapters::Field::Presenters::FieldUpdateHtmlPresenter.new(view: self)
    interactor = Domain::Field::Interactors::FieldUpdateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.field_gateway, user_lookup: CompositionRoot.user_lookup)
    interactor.call(input_dto)
  end

  # DELETE /farms/:farm_id/fields/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Adapters::Field::Presenters::FieldDestroyHtmlPresenter.new(view: self)
        interactor = Domain::Field::Interactors::FieldDestroyInteractor.new(output_port: presenter,
          user_id: current_user.id, gateway: CompositionRoot.field_gateway, user_lookup: CompositionRoot.user_lookup)
        interactor.call(params[:id])
      end
      format.json do
        presenter = Adapters::Field::Presenters::FieldDeleteApiPresenter.new(view: self)
        interactor = Domain::Field::Interactors::FieldDestroyInteractor.new(output_port: presenter,
          user_id: current_user.id, gateway: CompositionRoot.field_gateway, user_lookup: CompositionRoot.user_lookup)
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
    presenter = Adapters::Farm::Presenters::FarmLoadForEditHtmlPresenter.new(view: self)
    interactor = Domain::Farm::Interactors::FarmLoadAuthorizedModelForEditInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.farm_gateway, user_lookup: CompositionRoot.user_lookup)
    interactor.call(params[:farm_id])
  end

  def set_field
    failure_presenter = Adapters::Field::Presenters::FieldLoadInFarmAuthorizationFailureRedirectHtmlPresenter.new(view: self)
    interactor = Domain::Field::Interactors::FieldLoadAuthorizedInFarmInteractor.new(failure_presenter: failure_presenter,
      user_id: current_user.id, gateway: CompositionRoot.field_gateway, user_lookup: CompositionRoot.user_lookup)
    bundle = interactor.call(@farm.id, params[:id])
    return if bundle.nil?

    @field = Forms::FieldMasterForm.from_snapshot(bundle.master_form_snapshot)
  end

end
