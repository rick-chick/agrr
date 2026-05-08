# frozen_string_literal: true

require "test_helper"

class InteractionRuleDestroyHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success redirects back with success notice" do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleDestroyHtmlPresenter.new(view: view_mock)

    undo_event = mock("undo_event")
    undo_event.expects(:metadata).returns({ "resource_label" => "Test Rule" })
    destroy_output_dto = Domain::InteractionRule::Dtos::InteractionRuleDestroyOutputDto.new(undo: undo_event)

    view_mock.expects(:interaction_rules_path).returns("/interaction_rules")
    view_mock.expects(:redirect_back).with(
      fallback_location: "/interaction_rules",
      notice: I18n.t("deletion_undo.redirect_notice", resource: "Test Rule")
    )

    presenter.on_success(destroy_output_dto)
  end

  test "on_failure redirects back with error alert" do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleDestroyHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    view_mock.expects(:interaction_rules_path).returns("/interaction_rules")
    view_mock.expects(:redirect_back).with(
      fallback_location: "/interaction_rules",
      alert: "Test error"
    )

    presenter.on_failure(error_dto)
  end

  test "on_failure maps PolicyPermissionDenied to not_found flash" do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleDestroyHtmlPresenter.new(view: view_mock)

    view_mock.expects(:interaction_rules_path).returns("/interaction_rules")
    view_mock.expects(:redirect_back).with(
      fallback_location: "/interaction_rules",
      alert: I18n.t("interaction_rules.flash.not_found")
    )

    presenter.on_failure(Domain::Shared::Policies::PolicyPermissionDenied.new)
  end

  test "on_failure maps InteractionRule not found message to not_found flash" do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleDestroyHtmlPresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new("InteractionRule not found")

    view_mock.expects(:interaction_rules_path).returns("/interaction_rules")
    view_mock.expects(:redirect_back).with(
      fallback_location: "/interaction_rules",
      alert: I18n.t("interaction_rules.flash.not_found")
    )

    presenter.on_failure(error_dto)
  end
end
