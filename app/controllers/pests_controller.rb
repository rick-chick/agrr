# frozen_string_literal: true

class PestsController < ApplicationController
  before_action :load_pest_for_edit, only: [ :edit, :update ]

  # GET /pests
  def index
    presenter = Presenters::Html::Pest::PestListHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestListInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call
  end

  # GET /pests/:id
  def show
    presenter = Presenters::Html::Pest::PestDetailHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestDetailInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
  end

  # GET /pests/new
  def new
    @pest = CompositionRoot.pest_gateway.build_blank_pest_for_form
    prepare_crop_selection_for(@pest, selected_ids: normalize_crop_ids_for(@pest, params[:crop_ids]))
  end

  # GET /pests/:id/edit
  def edit
    CompositionRoot.pest_gateway.prepare_top_level_pest_for_edit_form!(@pest)
    prepare_crop_selection_for(@pest)
  end

  # POST /pests
  def create
    input_dto = Domain::Pest::Dtos::PestCreateInputDto.from_hash(
      { pest: pest_params.to_h.symbolize_keys, crop_ids: params[:crop_ids] }
    )
    presenter = Presenters::Html::Pest::PestCreateHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestCreateInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call(input_dto)
  end

  # PATCH/PUT /pests/:id
  def update
    input_dto = Domain::Pest::Dtos::PestUpdateInputDto.from_hash(
      { pest: pest_params.to_h.symbolize_keys, crop_ids: params[:crop_ids] },
      params[:id]
    )
    presenter = Presenters::Html::Pest::PestUpdateHtmlPresenter.new(
      view: self
    )
    Domain::Pest::Interactors::PestUpdateInteractor.new(output_port: presenter,
      user_id: current_user.id,
      translator: translator, gateway: CompositionRoot.pest_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup).call(input_dto)
  end

  # DELETE /pests/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Presenters::Html::Pest::PestDestroyHtmlPresenter.new(view: self)
        Domain::Pest::Interactors::PestDestroyInteractor.new(output_port: presenter,
          user_id: current_user.id,
          translator: translator, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
      end

      format.json do
        DeletionUndo::HtmlMasterScheduleInvoker.call(
          view: self,
          actor_id: current_user.id,
          resource_type: "Pest",
          resource_id: params[:id].to_i,
          toast_message: nil,
          fallback_location: pests_path,
          in_use_message_key: "pests.flash.cannot_delete_in_use",
          delete_error_message_key: "pests.flash.delete_error"
        )
      end
    end
  end

  private

  def translator
    @translator ||= CompositionRoot.translator
  end

  def load_pest_for_edit
    presenter = Presenters::Html::Pest::PestLoadForEditHtmlPresenter.new(view: self)
    Domain::Pest::Interactors::PestLoadAuthorizedModelForEditInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.pest_gateway, user_lookup: CompositionRoot.user_lookup).call(params[:id])
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

  public

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
