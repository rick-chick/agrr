# frozen_string_literal: true

module Presenters
  module Api
    module PublicPlan
      class PublicPlanCreatePresenter < Domain::PublicPlan::Ports::PublicPlanCreateOutputPort
        def initialize(view:, job_chain_async_dispatcher: nil)
          @view = view
          @job_chain_async_dispatcher = job_chain_async_dispatcher
        end

        def on_success(success_dto)
          plan_id = success_dto.plan_id

          # 契約に従い plan_id をログ出力
          Rails.logger.info "🌱 [PublicPlanCreatePresenter] Rendering success response with plan_id: #{plan_id}"

          # ジョブチェーンを実行（既存の動作を維持）。Dispatcher は Controller から注入（CompositionRoot は呼ばない）
          if @job_chain_async_dispatcher && @view.respond_to?(:public_plan_optimization_job_instances)
            job_instances = @view.public_plan_optimization_job_instances(plan_id)
            @job_chain_async_dispatcher.enqueue(
              job_instances,
              redirect_path: nil,
              caller_label: @view.class.name
            )
          end

          @view.render_response(
            json: { plan_id: plan_id },
            status: :ok
          )
        end

        def on_failure(failure_dto)
          error_message = failure_dto.respond_to?(:message) ? failure_dto.message : failure_dto.to_s

          # エラーメッセージに基づいて適切なステータスコードを決定
          status = case error_message
          when "Farm not found"
                     :not_found
          when "Invalid farm size", "Invalid total area", "No crops selected"
                     :unprocessable_entity
          when /Failed to create cultivation plan/
                     :internal_server_error
          else
                     # 予期しないエラー（StandardError など）は 500 を返す
                     :internal_server_error
          end

          @view.render_response(
            json: { error: error_message },
            status: status
          )
        end
      end
    end
  end
end
