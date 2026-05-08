# frozen_string_literal: true

module Api
  module V1
    class PlansController < BaseController
      include Views::Api::CultivationPlan::CultivationPlanDeleteView

      def index
        presenter = Presenters::Api::Plans::ApiV1PrivatePlansListPresenter.new(view: self, translator: translator)
        Domain::CultivationPlan::Interactors::ApiV1PrivatePlansListInteractor.new(
          output_port: presenter,
          user_id: current_user.id,
          gateway: CompositionRoot.cultivation_plan_gateway,
          translator: translator,
          logger: CompositionRoot.logger,
          user_lookup: CompositionRoot.user_lookup
        ).call
      end

      def show
        presenter = Presenters::Api::Plans::ApiV1PrivatePlanShowPresenter.new(view: self)
        Domain::CultivationPlan::Interactors::ApiV1PrivatePlanShowInteractor.new(
          output_port: presenter,
          user_id: current_user.id,
          gateway: CompositionRoot.cultivation_plan_gateway,
          translator: translator,
          logger: CompositionRoot.logger,
          user_lookup: CompositionRoot.user_lookup
        ).call(plan_id: params[:id])
      end

      def create
        presenter = Presenters::Api::Plans::ApiPrivatePlanCreatePresenter.new(view: self)
        input_dto = Domain::CultivationPlan::Dtos::ApiPrivatePlanCreateInputDto.new(
          farm_id: create_params[:farm_id],
          crop_ids: create_params[:crop_ids] || [],
          plan_name: create_params[:plan_name],
          user: current_user
        )
        Domain::CultivationPlan::Interactors::ApiV1PrivatePlanCreateInteractor.new(
          output_port: presenter,
          cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
          logger: CompositionRoot.logger,
          translator: translator,
          clock: Time.zone,
          session_id_generator: -> { SecureRandom.hex(16) },
          job_chain_enqueuer: CompositionRoot.api_private_plan_job_chain_enqueuer
        ).call(input_dto)
      end

      # Delete per docs/contracts/plan-delete-no-confirm-contract.md:
      # - calls the destroy interactor immediately (no confirmation dialog is necessary)
      # - renders the DeletionUndoResponse through the presenter/view contract
      def destroy
        presenter = Presenters::Api::CultivationPlan::CultivationPlanDeletePresenter.new(view: self)
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
