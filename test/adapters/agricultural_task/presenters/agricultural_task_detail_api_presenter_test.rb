# frozen_string_literal: true

require "test_helper"

class AgriculturalTaskDetailApiPresenterTest < ActiveSupport::TestCase
  test "on_failure renders forbidden with translated message for policy errors" do
    view_mock = Minitest::Mock.new
    presenter = Adapters::AgriculturalTask::Presenters::AgriculturalTaskDetailApiPresenter.new(view: view_mock)

    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    view_mock.expect(:render_response, nil) do |json:, status:|
      assert_equal :forbidden, status
      assert_equal({ error: I18n.t("agricultural_tasks.flash.no_permission") }, json)
    end

    presenter.on_failure(error_dto)

    view_mock.verify
  end
end
