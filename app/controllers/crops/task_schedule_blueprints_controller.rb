# frozen_string_literal: true

module Crops
  class TaskScheduleBlueprintsController < ApplicationController
    before_action :set_crop
    before_action :set_blueprint, only: [ :update_position ]

    # PATCH /crops/:crop_id/task_schedule_blueprints/:id/update_position
    def update_position
      unless can_edit_crop?
        return render json: { error: I18n.t("crops.flash.no_permission") }, status: :forbidden
      end

      gdd_trigger = params[:gdd_trigger]&.to_f
      priority = params[:priority]&.to_i

      # バリデーション
      if gdd_trigger && gdd_trigger < 0
        return render json: { error: "gdd_trigger must be non-negative" }, status: :bad_request
      end

      if priority && priority < 0
        return render json: { error: "priority must be non-negative" }, status: :bad_request
      end

      out = CompositionRoot.crop_gateway.update_task_schedule_blueprint_position_mutation(
        crop: @crop,
        blueprint: @blueprint,
        gdd_trigger: gdd_trigger,
        priority: priority
      )

      unless out[:ok]
        status = out[:status] == :internal_server_error ? :internal_server_error : :unprocessable_entity
        return render json: { error: out[:error] }, status: status
      end

      render json: out[:payload], status: :ok
    end

    # DELETE /crops/:crop_id/task_schedule_blueprints/:id
    def destroy
      unless can_edit_crop?
        return render json: { error: I18n.t("crops.flash.no_permission") }, status: :forbidden
      end
      user = CompositionRoot.user_lookup.find(current_user.id)
      result = CompositionRoot.crop_gateway.delete_task_schedule_blueprint_bundle_in_crop!(
        user, @crop.id, params[:id].to_i
      )
      if result[:not_found]
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.remove("blueprint-card-#{params[:id]}") }
          format.json { render json: { error: I18n.t("crops.flash.blueprint_not_found") }, status: :not_found }
          format.html { head :not_found }
        end
        return
      end

      @blueprint_id = result[:blueprint_id_for_response]

      Rails.logger.info("🗑️ [TaskScheduleBlueprintsController] Deletion result: #{result.inspect}")

      reload = CompositionRoot.crop_gateway.reload_crop_after_task_schedule_blueprint_delete!(
        crop: @crop,
        blueprint_id_for_response: @blueprint_id
      )

      unless reload[:ok]
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("blueprint-card-#{params[:id]}", partial: "crops/task_schedule_blueprints/error", locals: { error: I18n.t("crops.flash.blueprint_delete_failed") }) }
          format.json { render json: { error: I18n.t("crops.flash.blueprint_delete_failed") }, status: :internal_server_error }
        end
        return
      end

      @crop = reload[:crop]
      @available_agricultural_tasks = reload[:available_agricultural_tasks]
      @selected_task_ids = reload[:selected_task_ids]

      respond_to do |format|
        format.html { head :no_content }
        format.turbo_stream
        format.json { render json: { message: I18n.t("crops.flash.blueprint_deleted") } }
      end
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

      @crop = bundle.persisted_crop
    end

    def set_blueprint
      failure = Presenters::Api::Crop::CropNestedRecordNotFoundJsonPresenter.new(
        view: self,
        error_message: I18n.t("crops.flash.blueprint_not_found")
      )
      interactor = Domain::Crop::Interactors::CropLoadAuthorizedCropTaskScheduleBlueprintInteractor.new(
        failure_presenter: failure,
        user_id: current_user.id,
        gateway: CompositionRoot.crop_gateway,
        user_lookup: CompositionRoot.user_lookup
      )
      bundle = interactor.call(@crop.id, params[:id])
      return if bundle.nil?

      @blueprint = bundle.persisted_blueprint
    end

    def can_edit_crop?
      admin_user? || (!@crop.is_reference && @crop.user_id == current_user.id)
    end

    def can_view_crop?
      @crop.is_reference || @crop.user_id == current_user.id || admin_user?
    end
  end
end
