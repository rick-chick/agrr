# frozen_string_literal: true

require "test_helper"

class InteractionRuleListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @interaction_rules and @reference_rules with entities" do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleListHtmlPresenter.new(view: view_mock)

    rule = mock

    view_mock.expects(:instance_variable_set).with(:@interaction_rules, [ rule ])
    view_mock.expects(:instance_variable_set).with(:@reference_rules, [])

    presenter.on_success({ interaction_rules: [ rule ], reference_rules: [] })
  end

  test "on_failure sets flash and empty arrays" do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleListHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:respond_to?).with(:message).returns(true)
    error_dto.expects(:message).returns("Test error")

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:instance_variable_set).with(:@interaction_rules, [])
    view_mock.expects(:instance_variable_set).with(:@reference_rules, [])

    presenter.on_failure(error_dto)
  end

  test "on_failure redirects back with no_permission for policy errors" do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleListHtmlPresenter.new(view: view_mock)

    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    view_mock.expects(:interaction_rules_path).returns("/interaction_rules")
    view_mock.expects(:redirect_back).with(
      fallback_location: "/interaction_rules",
      alert: I18n.t("interaction_rules.flash.no_permission")
    )

    presenter.on_failure(error_dto)
  end
end
