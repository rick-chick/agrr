# frozen_string_literal: true

require "test_helper"

class AgriculturalTaskUpdateApiPresenterTest < ActiveSupport::TestCase
  test "on_failure renders forbidden with translated message for policy errors" do
    view_mock = Minitest::Mock.new
    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskUpdateApiPresenter.new(view: view_mock)

    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    view_mock.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: I18n.t("agricultural_tasks.flash.no_permission") }, json)
    end

    presenter.on_failure(error_dto)

    view_mock.verify
  end

  test "on_failure renders forbidden for ReferenceFlagChangeDeniedFailure" do
    view_mock = Minitest::Mock.new
    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskUpdateApiPresenter.new(view: view_mock)
    msg = I18n.t("agricultural_tasks.flash.reference_flag_admin_only")
    error_dto = Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure.new(message: msg, resource_id: 3)

    view_mock.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: msg }, json)
    end

    presenter.on_failure(error_dto)

    view_mock.verify
  end
end
