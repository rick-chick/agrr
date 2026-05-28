# frozen_string_literal: true

module Api
  module V1
    # 栽培計画 REST（plans / public_plans）の共通アクション基底。
    # サブクラスで `cultivation_plan_rest_plan_data_available_crop_rows_gateway` を実装する。
    class CultivationPlanRestBaseController < ApplicationController
      # POST /api/v1/{plans|public_plans}/cultivation_plans/:id/add_crop
      # 作物追加: candidatesで最適日付を自動決定し、adjustで追加する
      def add_crop
        add_crop_adjust_sink = Adapters::CultivationPlan::Ports::AddCropAdjustResultCollector.new
        Domain::CultivationPlan::Interactors::AddCropInteractor.new(
          output: Adapters::CultivationPlan::Presenters::AddCropApiPresenter.new(
            view: self,
            translation_scope: api_cultivation_plan_translation_scope
          ),
          logger: cultivation_plan_rest_logger,
          plan_allocation_adjust: CompositionRoot.build_plan_allocation_adjust_interactor(
            output_port: add_crop_adjust_sink
          ),
          add_crop_crop_resolve: CompositionRoot.build_add_crop_crop_resolve(
            auth: cultivation_plan_rest_auth
          ),
          add_crop_adjust_result_sink: add_crop_adjust_sink,
          plan_gateway: CompositionRoot.cultivation_plan_gateway,
          plan_crop_gateway: CompositionRoot.cultivation_plan_rest_plan_crop_gateway,
          plan_allocation_candidates: CompositionRoot.plan_allocation_candidates_interactor
        ).call(
          auth: cultivation_plan_rest_auth,
          plan_id: params[:id].to_i,
          crop_id: params[:crop_id],
          field_id: params[:field_id],
          display_range: display_range_from_params,
          ui_filter_context: ui_filter_context
        )
      end

      # POST /api/v1/{plans|public_plans}/cultivation_plans/:id/add_field
      # 新しい圃場を追加
      def add_field
        Domain::CultivationPlan::Interactors::AddFieldInteractor.new(
          output: Adapters::CultivationPlan::Presenters::AddFieldApiPresenter.new(
            view: self,
            translation_scope: api_cultivation_plan_translation_scope
          ),
          plan_gateway: CompositionRoot.cultivation_plan_gateway,
          field_mutation_gateway: cultivation_plan_rest_field_mutation_gateway,
          events_gateway: CompositionRoot.cultivation_plan_rest_optimization_events_gateway,
          logger: cultivation_plan_rest_logger
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
          output: Adapters::CultivationPlan::Presenters::RemoveFieldApiPresenter.new(
            view: self,
            translation_scope: api_cultivation_plan_translation_scope
          ),
          plan_gateway: CompositionRoot.cultivation_plan_gateway,
          field_mutation_gateway: cultivation_plan_rest_field_mutation_gateway,
          events_gateway: CompositionRoot.cultivation_plan_rest_optimization_events_gateway,
          logger: cultivation_plan_rest_logger
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
          output_port: Adapters::CultivationPlan::Presenters::RetrieveCultivationPlanApiPresenter.new(
            view: self,
            translation_scope: api_cultivation_plan_translation_scope
          ),
          workbench_read_gateway: CompositionRoot.cultivation_plan_rest_workbench_read_gateway,
          available_crop_rows_gateway: cultivation_plan_rest_plan_data_available_crop_rows_gateway,
          logger: cultivation_plan_rest_logger
        ).call(auth: cultivation_plan_rest_auth, plan_id: params[:id].to_i)
      end

      # POST /api/v1/{plans|public_plans}/cultivation_plans/:id/adjust
      # 手修正後の再最適化
      #
      # このメソッドはDBに保存された天気データを再利用し、
      # 不要な天気予測を実行しないことで高速化されています
      def adjust
        moves = Adapters::CultivationPlan::AdjustMovesFromRequest.normalize(params[:moves] || [])
        CompositionRoot.build_plan_allocation_adjust_interactor(
          output_port: Adapters::CultivationPlan::Presenters::PlanAllocationAdjustApiPresenter.new(view: self)
        ).call(
          Domain::CultivationPlan::Dtos::PlanAllocationAdjustInput.new(
            plan_id: params[:id].to_i,
            moves: moves,
            auth: cultivation_plan_rest_auth
          )
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

      # Api::V1::Plans と PublicPlans で available_crops の解決規則が異なる
      def cultivation_plan_rest_plan_data_available_crop_rows_gateway
        raise NotImplementedError, "#{self.class}#cultivation_plan_rest_plan_data_available_crop_rows_gateway must be implemented"
      end

      # Api::V1::Plans::* と PublicPlans::* で I18n スコープを切り替える
      def api_cultivation_plan_translation_scope
        self.class.name.include?("::PublicPlans::") ? "public_plans" : "plans"
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
    end
  end
end
