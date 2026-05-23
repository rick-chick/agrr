# frozen_string_literal: true

module Api
  module V1
    module PublicPlans
      class WizardController < ApplicationController
        SESSION_MARKER_KEY = :public_plan_wizard_session_marker

        skip_before_action :authenticate_user!
        skip_before_action :verify_authenticity_token

        def farms
          region = params[:region].presence || locale_to_region(I18n.locale)
          presenter = Adapters::PublicPlan::Presenters::ReferenceFarmsApiPresenter.new(view: self)
          Domain::Farm::Interactors::FarmListReferenceForRegionInteractor.new(output_port: presenter, gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger).call(region)
        end

        def farm_sizes
          render json: farm_sizes_with_i18n
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

        def farm_sizes_with_i18n
          base_farm_sizes.map do |size|
            size.merge(
              name: I18n.t("public_plans.farm_sizes.#{size[:id]}.name"),
              description: I18n.t("public_plans.farm_sizes.#{size[:id]}.description")
            )
          end
        end

        def base_farm_sizes
          [
            { id: "home_garden", area_sqm: 30 },
            { id: "community_garden", area_sqm: 50 },
            { id: "rental_farm", area_sqm: 300 }
          ]
        end

        # id（文字列）または area_sqm（Integer）で一致させる。フロントが number で送っても 422 にしない。
        def find_farm_size(param)
          return nil if param.blank?

          farm_sizes_with_i18n.find do |size|
            size[:id].to_s == param.to_s || size[:area_sqm] == param.to_i
          end
        end

        def crop_ids
          ids = params[:crop_ids].presence || []
          ids.is_a?(Array) ? ids : Array(ids)
        end

        def locale_to_region(locale)
          case locale.to_s
          when "ja"
            "jp"
          when "us"
            "us"
          when "in"
            "in"
          else
            "jp"
          end
        end

      end
    end
  end
end
