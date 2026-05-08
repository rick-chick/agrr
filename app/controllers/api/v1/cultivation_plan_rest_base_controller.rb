# frozen_string_literal: true

module Api
  module V1
    # 栽培計画 REST（plans / public_plans）の共通アクション基底。
    # サブクラスで `cultivation_plan_rest_plan_data_available_crop_rows_gateway` と
    # `get_crop_for_add_crop` を実装する。
    class CultivationPlanRestBaseController < ApplicationController
      # POST /api/v1/{plans|public_plans}/cultivation_plans/:id/add_crop
      # 作物追加: candidatesで最適日付を自動決定し、adjustで追加する
      def add_crop
        Domain::CultivationPlan::Interactors::AddCropInteractor.new(
          output: Presenters::Api::CultivationPlan::AddCropPresenter.new(
            view: self,
            translation_scope: api_cultivation_plan_translation_scope
          ),
          add_crop_coordinator_gateway: CompositionRoot.cultivation_plan_rest_add_crop_coordinator_gateway(
            optimization_host: cultivation_plan_rest_add_crop_optimizer_bridge
          )
        ).call(
          auth: cultivation_plan_rest_auth,
          plan_id: params[:id].to_i,
          crop_id: params[:crop_id],
          field_id: params[:field_id],
          display_range: display_range_from_params,
          crop_resolver: cultivation_plan_rest_add_crop_crop_resolver_bridge
        )
      end

      # POST /api/v1/{plans|public_plans}/cultivation_plans/:id/add_field
      # 新しい圃場を追加
      def add_field
        Domain::CultivationPlan::Interactors::AddFieldInteractor.new(
          output: Presenters::Api::CultivationPlan::AddFieldPresenter.new(
            view: self,
            translation_scope: api_cultivation_plan_translation_scope
          ),
          field_mutation_gateway: cultivation_plan_rest_field_mutation_gateway
        ).call(
          auth: cultivation_plan_rest_auth,
          plan_id: params[:id].to_i,
          field_name: params[:field_name],
          field_area: params[:field_area],
          daily_fixed_cost: params[:daily_fixed_cost]
        )
      end

      # DELETE /api/v1/{plans|public_plans}/cultivation_plans/:id/remove_field/:field_id
      # 圃場を削除
      def remove_field
        Domain::CultivationPlan::Interactors::RemoveFieldInteractor.new(
          output: Presenters::Api::CultivationPlan::ApiRemoveFieldPresenter.new(
            view: self,
            translation_scope: api_cultivation_plan_translation_scope
          ),
          field_mutation_gateway: cultivation_plan_rest_field_mutation_gateway
        ).call(
          auth: cultivation_plan_rest_auth,
          plan_id: params[:id].to_i,
          field_id_param: params[:field_id]
        )
      end

      # GET /api/v1/{plans|public_plans}/cultivation_plans/:id/data
      # 栽培計画データを取得
      def data
        Domain::CultivationPlan::Interactors::RetrieveCultivationPlanInteractor.new(
          output: Presenters::Api::CultivationPlan::ApiPlanDataPresenter.new(
            view: self,
            translation_scope: api_cultivation_plan_translation_scope
          ),
          workbench_payload_gateway: cultivation_plan_rest_workbench_payload_gateway
        ).call(auth: cultivation_plan_rest_auth, plan_id: params[:id].to_i)
      end

      # POST /api/v1/{plans|public_plans}/cultivation_plans/:id/adjust
      # 手修正後の再最適化
      #
      # このメソッドはDBに保存された天気データを再利用し、
      # 不要な天気予測を実行しないことで高速化されています
      def adjust
        moves = Adapters::CultivationPlan::AdjustMovesFromRequest.normalize(params[:moves] || [])
        Domain::CultivationPlan::Interactors::ManualPlanAdjustInteractor.new(
          output: Presenters::Api::CultivationPlan::ApiPlanAdjustPresenter.new(view: self),
          adjust_gateway: CompositionRoot.cultivation_plan_rest_adjust_gateway
        ).call(
          auth: cultivation_plan_rest_auth,
          plan_id: params[:id].to_i,
          moves: moves
        )
      end

      private

      def cultivation_plan_rest_logger
        CompositionRoot.logger
      end

      def cultivation_plan_rest_auth
        Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.for_api_controller(self)
      end

      def cultivation_plan_rest_field_mutation_gateway
        CompositionRoot.cultivation_plan_rest_field_mutation_gateway
      end

      def cultivation_plan_rest_workbench_payload_gateway
        CompositionRoot.cultivation_plan_rest_workbench_payload_gateway(
          available_crop_rows_gateway: cultivation_plan_rest_plan_data_available_crop_rows_gateway
        )
      end

      # Api::V1::Plans と PublicPlans で available_crops の解決規則が異なる
      def cultivation_plan_rest_plan_data_available_crop_rows_gateway
        raise NotImplementedError, "#{self.class}#cultivation_plan_rest_plan_data_available_crop_rows_gateway must be implemented"
      end

      def cultivation_plan_rest_add_crop_optimizer_bridge
        @cultivation_plan_rest_add_crop_optimizer_bridge ||= Adapters::CultivationPlan::RestAddCropOptimizationHostBridge.new(self)
      end

      def cultivation_plan_rest_add_crop_crop_resolver_bridge
        Adapters::CultivationPlan::RestAddCropCropResolverBridge.new(self)
      end

      # Api::V1::Plans::* と PublicPlans::* で I18n スコープを切り替える
      def api_cultivation_plan_translation_scope
        self.class.name.include?("::PublicPlans::") ? "public_plans" : "plans"
      end

      def i18n_t(key)
        scope = @cultivation_plan&.plan_type == "private" ? "plans" : "public_plans"
        I18n.t("#{scope}.#{key}")
      end

      def ui_filter_context
        filter_keys = %i[display_start_date display_end_date filters ui_filters field_id crop_id]
        filter_keys.each_with_object({}) do |key, context|
          context[key] = params[key] if params.key?(key)
        end
      end

      def display_range_from_params
        range = {}
        if (start_date = parse_display_date(params[:display_start_date]))
          range[:start_date] = start_date
        end
        if (end_date = parse_display_date(params[:display_end_date]))
          range[:end_date] = end_date
        end
        range
      end

      def parse_display_date(value)
        Adapters::Shared::Iso8601CalendarDate.parse(value, logger: Rails.logger)
      end

      # add_crop で使用する作物を取得する（具象コントローラで実装）
      # @param crop_id [String, Integer] 作物ID
      # @return [Crop, nil] 作物オブジェクト
      def get_crop_for_add_crop(crop_id)
        raise NotImplementedError, "#{self.class}#get_crop_for_add_crop must be implemented"
      end
    end
  end
end
