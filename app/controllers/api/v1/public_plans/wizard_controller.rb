# frozen_string_literal: true

module Api
  module V1
    module PublicPlans
      class WizardController < ApplicationController
        SESSION_MARKER_KEY = :public_plan_wizard_session_marker

        skip_before_action :authenticate_user!
        skip_before_action :verify_authenticity_token

        def farms
          region = params[:region].presence || Domain::Shared::Mappers::LocaleToRegionMapper.call(I18n.locale)
          presenter = Adapters::PublicPlan::Presenters::ReferenceFarmsApiPresenter.new(view: self)
          Domain::Farm::Interactors::FarmListReferenceForRegionInteractor.new(output_port: presenter, gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger).call(region)
        end

        def farm_sizes
          sizes = CompositionRoot.public_plan_gateway.list_farm_sizes
          render json: Adapters::PublicPlan::Mappers::FarmSizeI18nMapper.enrich(sizes)
        end

        def crops
          Rails.logger.info "🌱 [WizardController#crops] Called with farm_id: #{params[:farm_id]}"
          presenter = Adapters::PublicPlan::Presenters::PublicPlanWizardCropsApiPresenter.new(view: self)
          Domain::PublicPlan::Interactors::PublicPlanWizardCropsInteractor.new(
            output_port: presenter,
            farm_gateway: CompositionRoot.farm_gateway,
            crop_gateway: CompositionRoot.crop_gateway,
            logger: CompositionRoot.logger
          ).call(farm_id: params[:farm_id])
        end

        def create
          Rails.logger.info "🌱 [WizardController#create] Called with farm_id: #{params[:farm_id]}, farm_size_id: #{params[:farm_size_id]}, crop_ids: #{params[:crop_ids]}"

          # Input DTO を作成
          input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInput.new(
            farm_id: params[:farm_id],
            farm_size_id: params[:farm_size_id],
            crop_ids: crop_ids,
            session_id: ensure_session_id_for_public_plan,
            user: nil
          )

          # Presenter と Gateway を準備
          presenter = Adapters::PublicPlan::Presenters::PublicPlanCreateApiPresenter.new(view: self)

          # Interactor を実行（成功時は presenter が render、ジョブチェーンは Interactor 経由で注入ゲートウェイが処理）
          interactor = Domain::PublicPlan::Interactors::PublicPlanCreateInteractor.new(
            output_port: presenter,
            gateway: CompositionRoot.public_plan_gateway,
            crop_gateway: CompositionRoot.crop_gateway,
            cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
            logger: CompositionRoot.logger,
            clock: Time.zone,
            optimization_job_chain_gateway: CompositionRoot.public_plan_optimization_job_chain_gateway
          )

          interactor.call(input_dto)
        end

        def render_response(json:, status:)
          render json: json, status: status
        end

        private

        def ensure_session_id_for_public_plan
          # If the underlying session has an id, use it. Otherwise generate a stable random id.
          return session.id.to_s if session.id.present?

          SecureRandom.hex(32)
        end

        def crop_ids
          ids = params[:crop_ids].presence || []
          ids.is_a?(Array) ? ids : Array(ids)
        end

      end
    end
  end
end
