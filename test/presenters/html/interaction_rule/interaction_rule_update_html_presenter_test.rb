# frozen_string_literal: true

require "test_helper"

class InteractionRuleUpdateHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success redirects with success notice" do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleUpdateHtmlPresenter.new(view: view_mock)

    rule_entity = mock
    rule_entity.expects(:id).returns(1)

    view_mock.expects(:interaction_rule_path).with(1).returns("/interaction_rules/1")
    view_mock.expects(:redirect_to).with("/interaction_rules/1", notice: I18n.t("interaction_rules.flash.updated"))

    presenter.on_success(rule_entity)
    assert true
  end

  test "on_failure renders edit template" do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleUpdateHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    flash_now = mock
    flash_now.expects(:[]=).with(:alert, "Test error")
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now)
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:render).with(:edit, status: :unprocessable_entity)

    presenter.on_failure(error_dto)
  end
end
