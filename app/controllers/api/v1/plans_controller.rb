# frozen_string_literal: true

module Api
  module V1
    class PlansController < BaseController

      def index
        presenter = Adapters::CultivationPlan::Presenters::PrivateOwnedPlansListApiPresenter.new(view: self, translator: translator)
        Domain::CultivationPlan::Interactors::PrivateOwnedPlansListInteractor.new(
          output_port: presenter,
          user_id: current_user.id,
          private_read_gateway: CompositionRoot.cultivation_plan_private_read_gateway,
          translator: translator,
          logger: CompositionRoot.logger,
          user_lookup: CompositionRoot.user_lookup
        ).call
      end

      def show
        presenter = Adapters::CultivationPlan::Presenters::PrivateOwnedPlanDetailApiPresenter.new(view: self)
        Domain::CultivationPlan::Interactors::PrivateOwnedPlanDetailInteractor.new(
          output_port: presenter,
          user_id: current_user.id,
          private_read_gateway: CompositionRoot.cultivation_plan_private_read_gateway,
          cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
          crop_gateway: CompositionRoot.crop_gateway,
          translator: translator,
          logger: CompositionRoot.logger,
          user_lookup: CompositionRoot.user_lookup
        ).call(plan_id: params[:id])
      end

      def create
        presenter = Adapters::CultivationPlan::Presenters::PrivatePlanInitializeFromSelectionApiPresenter.new(view: self)
        input_dto = Domain::CultivationPlan::Dtos::PrivatePlanInitializeFromSelectionInput.new(
          farm_id: create_params[:farm_id],
          crop_ids: create_params[:crop_ids] || [],
          plan_name: create_params[:plan_name],
          user: current_user
        )
        Domain::CultivationPlan::Interactors::PrivatePlanInitializeFromSelectionInteractor.new(
          output_port: presenter,
          cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
          farm_gateway: CompositionRoot.farm_gateway,
          crop_gateway: CompositionRoot.crop_gateway,
          field_gateway: CompositionRoot.field_gateway,
          plan_initializer: CompositionRoot.cultivation_plan_plan_initializer,
          logger: CompositionRoot.logger,
          translator: translator,
          clock: Time.zone,
          session_id_generator: -> { SecureRandom.hex(16) },
          job_chain_enqueuer: CompositionRoot.api_private_plan_job_chain_enqueuer
        ).call(input_dto)
      end

      # Delete (see test/controllers/api/v1/plans_controller_test.rb "destroy deletes plan"):
      # - calls the destroy interactor immediately (no confirmation dialog)
      # - renders DeletionUndoResponse fields via CultivationPlanDeleteApiPresenter
      def destroy
        presenter = Adapters::CultivationPlan::Presenters::CultivationPlanDeleteApiPresenter.new(view: self)
        interactor = Domain::CultivationPlan::Interactors::CultivationPlanDestroyInteractor.new(output_port: presenter,
          user_id: current_user.id,
          translator: translator, gateway: CompositionRoot.cultivation_plan_gateway, user_lookup: CompositionRoot.user_lookup)
        interactor.call(params[:id])
      end

      def render_response(json:, status:)
        render(json: json, status: status)
      end

      def undo_deletion_path(undo_token:)
        Rails.application.routes.url_helpers.undo_deletion_path(undo_token: undo_token)
      end

      private

      def create_params
        params.require(:plan).permit(:farm_id, :plan_name, crop_ids: [])
      end
    end
  end
end
