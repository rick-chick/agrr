# frozen_string_literal: true

require "test_helper"

class AgriculturalTaskApiPresentersPolicyTest < ActiveSupport::TestCase
  # List / Detail / Create / Update / Delete は on_failure の policy 分岐が同一のため、
  # 契約は 1 本で表明し、Interactor 側の policy 拒否と二重に列を増やさない。
  # Create は policy 拒否を 422 errors に写すため含めない（Interactor 側で表明）。
  AGRICULTURAL_TASK_API_PRESENTERS_POLICY_BRANCH = [
    Adapters::AgriculturalTask::Presenters::AgriculturalTaskListApiPresenter,
    Adapters::AgriculturalTask::Presenters::AgriculturalTaskDetailApiPresenter,
    Adapters::AgriculturalTask::Presenters::AgriculturalTaskUpdateApiPresenter,
    Adapters::AgriculturalTask::Presenters::AgriculturalTaskDeleteApiPresenter
  ].freeze

  test "agricultural task API presenters render forbidden with no_permission for policy denial" do
    expected = { error: I18n.t("agricultural_tasks.flash.no_permission") }
    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    AGRICULTURAL_TASK_API_PRESENTERS_POLICY_BRANCH.each do |klass|
      view = Minitest::Mock.new
      presenter = klass.new(view: view)

      view.expect(:render_response, nil) do |json:, status:|
        assert_equal :forbidden, status
        assert_equal(expected, json)
      end

      presenter.on_failure(error_dto)
      view.verify
    end
  end

  test "update presenter on_failure renders forbidden for reference_flag_admin_only" do
    view = Minitest::Mock.new
    msg = I18n.t("agricultural_tasks.flash.reference_flag_admin_only")
    error_dto = Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure.new(message: msg, resource_id: 3)

    view.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: msg }, json)
    end

    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskUpdateApiPresenter.new(view: view)
    presenter.on_failure(error_dto)
    view.verify
  end
end
