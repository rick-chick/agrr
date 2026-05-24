# frozen_string_literal: true

class FieldsController < ApplicationController
  # GET /farms/:farm_id/fields
  def index
    presenter = Adapters::Field::Presenters::FieldListHtmlPresenter.new(view: self)
    interactor = Domain::Field::Interactors::FieldListInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.field_gateway, user_lookup: CompositionRoot.user_lookup)
    interactor.call(params[:farm_id])
    return if performed?
  end

  # GET /farms/:farm_id/fields/:id
  def show
    presenter = Adapters::Field::Presenters::FieldDetailHtmlPresenter.new(view: self)
    interactor = Domain::Field::Interactors::FieldDetailInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.field_gateway, user_lookup: CompositionRoot.user_lookup)
    input = Domain::Field::Dtos::FieldDetailInput.new(field_id: params[:id], farm_id: params[:farm_id])
    interactor.call(input)
    return if performed?
  end

  # GET /farms/:farm_id/fields/:id/edit
  def edit
    presenter = Adapters::Field::Presenters::FieldEditMasterFormHtmlPresenter.new(view: self)
    input = Domain::Field::Dtos::FieldLoadAuthorizedInFarmInput.new(
      farm_id: params[:farm_id],
      field_id: params[:id]
    )
    Domain::Field::Interactors::FieldEditMasterFormInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: CompositionRoot.field_gateway,
      farm_gateway: CompositionRoot.farm_gateway,
      user_lookup: CompositionRoot.user_lookup
    ).call(input)
    return if performed?
  end

  # POST /farms/:farm_id/fields
  def create
    input_dto = Domain::Field::Dtos::FieldCreateInput.from_hash(
      params.to_unsafe_h.deep_symbolize_keys,
      farm_id: params[:farm_id]
    )
    presenter = Adapters::Field::Presenters::FieldCreateHtmlPresenter.new(view: self)
    interactor = Domain::Field::Interactors::FieldCreateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.field_gateway, user_lookup: CompositionRoot.user_lookup)
    interactor.call(input_dto)
    return if performed?
  end

  # PATCH/PUT /farms/:farm_id/fields/:id
  def update
    input_dto = Domain::Field::Dtos::FieldUpdateInput.from_hash(params.to_unsafe_h.deep_symbolize_keys, params[:id])
    presenter = Adapters::Field::Presenters::FieldUpdateHtmlPresenter.new(view: self)
    interactor = Domain::Field::Interactors::FieldUpdateInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.field_gateway, user_lookup: CompositionRoot.user_lookup)
    interactor.call(input_dto)
    return if performed?
  end

  # DELETE /farms/:farm_id/fields/:id
  def destroy
    presenter = Adapters::Field::Presenters::FieldDestroyHtmlPresenter.new(view: self)
    interactor = Domain::Field::Interactors::FieldDestroyInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.field_gateway,
      translator: CompositionRoot.translator, user_lookup: CompositionRoot.user_lookup)
    interactor.call(params[:id])
    return if performed?
  end

  def render_form(action, status: :ok, locals: {})
    render(action, status: status, locals: locals)
  end

end
