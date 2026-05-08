# frozen_string_literal: true

require "test_helper"

class InteractionRuleDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success does nothing" do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleDetailHtmlPresenter.new(view: view_mock)

    rule = mock("rule")
    view_mock.expects(:instance_variable_set).with(:@interaction_rule, rule)

    presenter.on_success(rule)
  end

  test "on_failure renders error template" do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleDetailHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    view_mock.expects(:render).with(:error, status: :internal_server_error, locals: { error: "Test error" })

    presenter.on_failure(error_dto)
  end
end
