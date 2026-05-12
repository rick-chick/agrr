# frozen_string_literal: true

module Crops
  class TaskScheduleBlueprintsController < ApplicationController
    before_action :set_crop

    # PATCH /crops/:crop_id/task_schedule_blueprints/:id/update_position
    def update_position
      input_dto = Domain::Crop::Dtos::CropTaskScheduleBlueprintUpdatePositionInputDto.new(
        user_id: current_user.id,
        crop_id: params[:crop_id],
        blueprint_id: params[:id].to_i,
        gdd_trigger: params[:gdd_trigger]&.to_f,
        priority: params[:priority]&.to_i
      )
      presenter = Presenters::Html::Crop::CropTaskScheduleBlueprintUpdatePositionPresenter.new(view: self)
      Domain::Crop::Interactors::CropTaskScheduleBlueprintUpdatePositionInteractor.new(
        output_port: presenter,
        gateway: CompositionRoot.crop_gateway,
        user_lookup: CompositionRoot.user_lookup
      ).call(input_dto)
    end

    # DELETE /crops/:crop_id/task_schedule_blueprints/:id
    def destroy
      input_dto = Domain::Crop::Dtos::CropTaskScheduleBlueprintDestroyInputDto.new(
        user_id: current_user.id,
        crop_id: params[:crop_id],
        blueprint_id: params[:id].to_i
      )
      presenter = Presenters::Html::Crop::CropTaskScheduleBlueprintDestroyPresenter.new(view: self)
      Domain::Crop::Interactors::CropTaskScheduleBlueprintDestroyInteractor.new(
        output_port: presenter,
        gateway: CompositionRoot.crop_gateway,
        user_lookup: CompositionRoot.user_lookup
      ).call(input_dto)
    end

    private

    def set_crop
      failure = Presenters::Html::Crop::CropAuthorizationFailureRedirectPresenter.new(view: self, permission_message_key: "crops.flash.no_permission")
      interactor = Domain::Crop::Interactors::CropLoadAuthorizedInteractor.new(
        failure_presenter: failure,
        user_id: current_user.id,
        gateway: CompositionRoot.crop_gateway,
        user_lookup: CompositionRoot.user_lookup
      )
      bundle = interactor.call(params[:crop_id], for_edit: false)
      return if bundle.nil?

      @crop = Forms::CropMasterForm.from_snapshot(bundle.master_form_snapshot)
    end
  end
end
