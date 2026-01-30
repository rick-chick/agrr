# frozen_string_literal: true

require 'test_helper'

class InteractionRuleListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success does nothing' do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleListHtmlPresenter.new(view: view_mock)

    result = { interaction_rules: [mock('rule')], reference_rules: [] }
    presenter.on_success(result)
    assert true
  end

  test 'on_failure renders error template' do
    view_mock = mock
    presenter = Presenters::Html::InteractionRule::InteractionRuleListHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    view_mock.expects(:render).with(:error, status: :internal_server_error, locals: { error: 'Test error' })

    presenter.on_failure(error_dto)
    assert true
  end
end