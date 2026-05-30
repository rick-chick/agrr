# frozen_string_literal: true

# 公開プラン保存の統合テスト用（本番と同じ PublicPlanSaveInteractor 経路）。
module PublicPlanSaveTestSupport
  class SaveResult
    attr_accessor :success, :error_message, :new_plan, :failure_kind
    attr_reader :skipped_items

    def initialize
      @success = false
      @error_message = nil
      @new_plan = nil
      @failure_kind = nil
      @skipped_items = {
        farm: [], fields: [], crops: [], fertilizes: [], pests: [],
        agricultural_tasks: [], pesticides: [], interaction_rules: [], plan: []
      }
    end

    def success?
      success
    end

    def skipped?
      @skipped_items.values.any?(&:present?)
    end
  end

  class CapturingOutputPort < Domain::CultivationPlan::Ports::PublicPlanSaveFromSessionOutputPort
    attr_reader :failure_dto, :success_dto

    def initialize
      @success_called = false
    end

    def success_called?
      @success_called
    end

    def on_success(success = nil)
      @success_called = true
      @success_dto = success
    end

    def on_failure(failure)
      @failure_dto = failure
    end
  end

  # 永続化 port の戻り値（skipped_items 等）を統合テスト用に保持する。
  class CapturingPersistencePort < Domain::CultivationPlan::Ports::PublicPlanSavePersistencePort
    attr_reader :last_output

    def initialize(delegate)
      @delegate = delegate
    end

    def execute_save!(workspace:)
      @last_output = @delegate.execute_save!(workspace: workspace)
    end
  end

  module_function

  # POST /api/v1/public_plans/save_plan と同じ経路（session_data は Interactor が DB から解決）
  def invoke_save_api(user:, plan_id:)
    input = Domain::CultivationPlan::Dtos::PublicPlanSaveInput.new(
      plan_id: plan_id,
      user_id: user.id,
      session_data: nil
    )

    output_port = CapturingOutputPort.new
    persistence_port = CapturingPersistencePort.new(CompositionRoot.public_plan_save_persistence_port)

    Domain::CultivationPlan::Interactors::PublicPlanSaveInteractor.new(
      output_port: output_port,
      txn_gateway: CompositionRoot.cultivation_plan_gateway,
      read_gateway: CompositionRoot.public_plan_save_read_gateway,
      farm_gateway: CompositionRoot.farm_gateway,
      persistence_port: persistence_port,
      logger: CompositionRoot.logger,
      translator: CompositionRoot.translator
    ).call(input)

    build_save_result(output_port: output_port, persistence_output: persistence_port.last_output, user: user)
  end

  def invoke_save(user:, session_data:)
    session_dto = normalize_session_data(session_data)
    input = Domain::CultivationPlan::Dtos::PublicPlanSaveInput.new(
      plan_id: session_dto.plan_id,
      user_id: user.id,
      session_data: session_dto
    )

    output_port = CapturingOutputPort.new
    persistence_port = CapturingPersistencePort.new(CompositionRoot.public_plan_save_persistence_port)

    Domain::CultivationPlan::Interactors::PublicPlanSaveInteractor.new(
      output_port: output_port,
      txn_gateway: CompositionRoot.cultivation_plan_gateway,
      read_gateway: CompositionRoot.public_plan_save_read_gateway,
      farm_gateway: CompositionRoot.farm_gateway,
      persistence_port: persistence_port,
      logger: CompositionRoot.logger,
      translator: CompositionRoot.translator
    ).call(input)

    build_save_result(output_port: output_port, persistence_output: persistence_port.last_output, user: user)
  end

  def normalize_session_data(session_data)
    return session_data if session_data.is_a?(Domain::CultivationPlan::Dtos::PublicPlanSaveSessionData)

    hash = if session_data.respond_to?(:to_unsafe_h)
      session_data.to_unsafe_h
    else
      session_data
    end
    Domain::CultivationPlan::Dtos::PublicPlanSaveSessionData.from_session_hash(hash)
  end

  def build_save_result(output_port:, persistence_output:, user:)
    result = SaveResult.new

    if output_port.success_called?
      result.success = true
      if persistence_output&.new_cultivation_plan_id
        result.new_plan = ::CultivationPlan.find_by(id: persistence_output.new_cultivation_plan_id)
      end
      merge_skipped_items(result, persistence_output)
    elsif output_port.failure_dto
      result.success = false
      result.failure_kind = output_port.failure_dto.kind
      result.error_message = output_port.failure_dto.message
    end

    result
  end

  def merge_skipped_items(result, persistence_output)
    return unless persistence_output&.skipped_items.is_a?(Hash)

    persistence_output.skipped_items.each do |k, v|
      result.skipped_items[k] = v if result.skipped_items.key?(k)
    end
  end
end
